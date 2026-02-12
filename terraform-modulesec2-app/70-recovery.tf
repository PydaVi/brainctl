# ==========================================================
# Recovery mode (daily snapshots + runbooks)
# ==========================================================
resource "aws_iam_role" "dlm" {
  count = var.enable_recovery_mode ? 1 : 0
  name  = "${var.name}-${var.environment}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dlm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-role"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count      = var.enable_recovery_mode ? 1 : 0
  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "app_daily" {
  count              = var.enable_recovery_mode && var.recovery_backup_app ? 1 : 0
  description        = "Daily APP snapshots for ${var.name}-${var.environment}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      App         = var.name
      Environment = var.environment
      BackupScope = "app"
    }

    schedule {
      name = "daily-app-snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.recovery_snapshot_time_utc]
      }

      retain_rule {
        count = var.recovery_retention_days
      }

      copy_tags = true
      tags_to_add = {
        ManagedBy   = "brainctl"
        App         = var.name
        Environment = var.environment
        BackupScope = "app"
      }
    }
  }

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-app"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}

resource "aws_dlm_lifecycle_policy" "db_daily" {
  count              = var.enable_recovery_mode && var.recovery_backup_db && var.enable_db ? 1 : 0
  description        = "Daily DB snapshots for ${var.name}-${var.environment}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      App         = var.name
      Environment = var.environment
      BackupScope = "db"
    }

    schedule {
      name = "daily-db-snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.recovery_snapshot_time_utc]
      }

      retain_rule {
        count = var.recovery_retention_days
      }

      copy_tags = true
      tags_to_add = {
        ManagedBy   = "brainctl"
        App         = var.name
        Environment = var.environment
        BackupScope = "db"
      }
    }
  }

  tags = {
    Name        = "${var.name}-${var.environment}-dlm-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}

resource "aws_ssm_document" "recovery_app_runbook" {
  count           = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  name            = "${var.name}-${var.environment}-recovery-app"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Runbook APP recovery: encontra snapshot mais recente e cria volume EBS"
    assumeRole    = "{{AutomationAssumeRole}}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        default     = ""
        description = "(Opcional) IAM role ARN para executar automação"
      }
      AvailabilityZone = {
        type        = "String"
        description = "Availability Zone para criação do volume (ex: us-east-1a)"
      }
      VolumeType = {
        type        = "String"
        default     = "gp3"
        description = "Tipo do volume EBS de recuperação"
      }
    }
    mainSteps = [
      {
        name   = "FindAppSnapshots"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeSnapshots"
          Filters = [
            { Name = "tag:App", Values = [var.name] },
            { Name = "tag:Environment", Values = [var.environment] },
            { Name = "tag:BackupScope", Values = ["app"] }
          ]
          OwnerIds = [data.aws_caller_identity.current.account_id]
        }
        outputs = [{ Name = "Snapshots", Selector = "$.Snapshots", Type = "MapList" }]
      },
      {
        name   = "SelectLatestAppSnapshot"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.11"
          Handler = "handler"
          Script  = "def handler(events, context):\n    snaps = events.get('Snapshots', [])\n    if not snaps:\n        raise Exception('No APP snapshots found')\n    snaps.sort(key=lambda x: x.get('StartTime', ''), reverse=True)\n    return {'SnapshotId': snaps[0]['SnapshotId']}"
          InputPayload = {
            Snapshots = "{{FindAppSnapshots.Snapshots}}"
          }
        }
        outputs = [{ Name = "SnapshotId", Selector = "$.Payload.SnapshotId", Type = "String" }]
      },
      {
        name   = "CreateAppRecoveryVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service          = "ec2"
          Api              = "CreateVolume"
          SnapshotId       = "{{SelectLatestAppSnapshot.SnapshotId}}"
          AvailabilityZone = "{{AvailabilityZone}}"
          VolumeType       = "{{VolumeType}}"
          TagSpecifications = [{
            ResourceType = "volume"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-app-recovery" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "BackupScope", Value = "app" }
            ]
          }]
        }
        outputs = [{ Name = "VolumeId", Selector = "$.VolumeId", Type = "String" }]
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-recovery-app"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}

resource "aws_ssm_document" "recovery_db_runbook" {
  count           = var.enable_recovery_mode && var.recovery_enable_runbooks && var.recovery_backup_db && var.enable_db ? 1 : 0
  name            = "${var.name}-${var.environment}-recovery-db"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Runbook DB recovery: encontra snapshot mais recente e cria volume EBS"
    assumeRole    = "{{AutomationAssumeRole}}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        default     = ""
        description = "(Opcional) IAM role ARN para executar automação"
      }
      AvailabilityZone = {
        type        = "String"
        description = "Availability Zone para criação do volume (ex: us-east-1a)"
      }
      VolumeType = {
        type        = "String"
        default     = "gp3"
        description = "Tipo do volume EBS de recuperação"
      }
    }
    mainSteps = [
      {
        name   = "FindDBSnapshots"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeSnapshots"
          Filters = [
            { Name = "tag:App", Values = [var.name] },
            { Name = "tag:Environment", Values = [var.environment] },
            { Name = "tag:BackupScope", Values = ["db"] }
          ]
          OwnerIds = [data.aws_caller_identity.current.account_id]
        }
        outputs = [{ Name = "Snapshots", Selector = "$.Snapshots", Type = "MapList" }]
      },
      {
        name   = "SelectLatestDBSnapshot"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.11"
          Handler = "handler"
          Script  = "def handler(events, context):\n    snaps = events.get('Snapshots', [])\n    if not snaps:\n        raise Exception('No DB snapshots found')\n    snaps.sort(key=lambda x: x.get('StartTime', ''), reverse=True)\n    return {'SnapshotId': snaps[0]['SnapshotId']}"
          InputPayload = {
            Snapshots = "{{FindDBSnapshots.Snapshots}}"
          }
        }
        outputs = [{ Name = "SnapshotId", Selector = "$.Payload.SnapshotId", Type = "String" }]
      },
      {
        name   = "CreateDBRecoveryVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service          = "ec2"
          Api              = "CreateVolume"
          SnapshotId       = "{{SelectLatestDBSnapshot.SnapshotId}}"
          AvailabilityZone = "{{AvailabilityZone}}"
          VolumeType       = "{{VolumeType}}"
          TagSpecifications = [{
            ResourceType = "volume"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-db-recovery" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "BackupScope", Value = "db" }
            ]
          }]
        }
        outputs = [{ Name = "VolumeId", Selector = "$.VolumeId", Type = "String" }]
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-recovery-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
