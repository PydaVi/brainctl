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
      SubnetId = {
        type        = "String"
        default     = "${var.app_recovery_subnet_id}"
        description = "Subnet para instância restaurada"
      }
      SecurityGroupId = {
        type        = "String"
        default     = "${var.app_recovery_security_group_id}"
        description = "Security group para instância restaurada"
      }
      ImageId = {
        type        = "String"
        default     = "${var.app_recovery_ami_id}"
        description = "AMI para instância restaurada"
      }
      InstanceType = {
        type        = "String"
        default     = "${var.app_recovery_instance_type}"
        description = "Tipo da instância restaurada"
      }
      IamInstanceProfileName = {
        type        = "String"
        default     = "${var.app_recovery_instance_profile_name}"
        description = "Instance profile (opcional)"
      }
      RegisterToTargetGroup = {
        type        = "Boolean"
        default     = false
        description = "Registra instância restaurada no Target Group"
      }
      TargetGroupArn = {
        type        = "String"
        default     = ""
        description = "ARN do Target Group para registro opcional"
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
      },
      {
        name   = "WaitUntilAppVolumeAvailable"
        action = "aws:waitForAwsResourceProperty"
        timeoutSeconds = 900
        inputs = {
          Service          = "ec2"
          Api              = "DescribeVolumes"
          VolumeIds        = ["{{CreateAppRecoveryVolume.VolumeId}}"]
          PropertySelector = "$.Volumes[0].State"
          DesiredValues    = ["available"]
        }
      },
      {
        name   = "LaunchRecoveredAppInstance"
        action = "aws:executeAwsApi"
        inputs = {
          Service      = "ec2"
          Api          = "RunInstances"
          ImageId      = "{{ImageId}}"
          InstanceType = "{{InstanceType}}"
          MinCount     = 1
          MaxCount     = 1
          SubnetId     = "{{SubnetId}}"
          SecurityGroupIds = ["{{SecurityGroupId}}"]
          IamInstanceProfile = { Name = "{{IamInstanceProfileName}}" }
          TagSpecifications = [{
            ResourceType = "instance"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-app-drill" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "Role", Value = "app-recovery" }
            ]
          }]
        }
        outputs = [{ Name = "InstanceId", Selector = "$.Instances[0].InstanceId", Type = "String" }]
      },
      {
        name   = "WaitUntilAppInstanceRunning"
        action = "aws:waitForAwsResourceProperty"
        timeoutSeconds = 900
        inputs = {
          Service          = "ec2"
          Api              = "DescribeInstances"
          InstanceIds      = ["{{LaunchRecoveredAppInstance.InstanceId}}"]
          PropertySelector = "$.Reservations[0].Instances[0].State.Name"
          DesiredValues    = ["running"]
        }
      },
      {
        name   = "AttachRecoveredVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "ec2"
          Api        = "AttachVolume"
          Device     = "/dev/sdf"
          InstanceId = "{{LaunchRecoveredAppInstance.InstanceId}}"
          VolumeId   = "{{CreateAppRecoveryVolume.VolumeId}}"
        }
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
      SubnetId = {
        type        = "String"
        default     = "${var.db_recovery_subnet_id}"
        description = "Subnet para instância restaurada"
      }
      SecurityGroupId = {
        type        = "String"
        default     = "${var.db_recovery_security_group_id}"
        description = "Security group para instância restaurada"
      }
      ImageId = {
        type        = "String"
        default     = "${var.db_recovery_ami_id}"
        description = "AMI para instância restaurada"
      }
      InstanceType = {
        type        = "String"
        default     = "${var.db_recovery_instance_type}"
        description = "Tipo da instância restaurada"
      }
      IamInstanceProfileName = {
        type        = "String"
        default     = "${var.db_recovery_instance_profile_name}"
        description = "Instance profile (opcional)"
      }
      RegisterToTargetGroup = {
        type        = "Boolean"
        default     = false
        description = "Registra instância restaurada no Target Group"
      }
      TargetGroupArn = {
        type        = "String"
        default     = ""
        description = "ARN do Target Group para registro opcional"
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
      },
      {
        name   = "WaitUntilDBVolumeAvailable"
        action = "aws:waitForAwsResourceProperty"
        timeoutSeconds = 900
        inputs = {
          Service          = "ec2"
          Api              = "DescribeVolumes"
          VolumeIds        = ["{{CreateDBRecoveryVolume.VolumeId}}"]
          PropertySelector = "$.Volumes[0].State"
          DesiredValues    = ["available"]
        }
      },
      {
        name   = "LaunchRecoveredDBInstance"
        action = "aws:executeAwsApi"
        inputs = {
          Service           = "ec2"
          Api               = "RunInstances"
          ImageId           = "{{ImageId}}"
          InstanceType      = "{{InstanceType}}"
          MinCount          = 1
          MaxCount          = 1
          SubnetId          = "{{SubnetId}}"
          SecurityGroupIds  = ["{{SecurityGroupId}}"]
          IamInstanceProfile = { Name = "{{IamInstanceProfileName}}" }
          TagSpecifications = [{
            ResourceType = "instance"
            Tags = [
              { Key = "Name", Value = "${var.name}-${var.environment}-db-drill" },
              { Key = "ManagedBy", Value = "brainctl" },
              { Key = "App", Value = var.name },
              { Key = "Environment", Value = var.environment },
              { Key = "Role", Value = "db-recovery" }
            ]
          }]
        }
        outputs = [{ Name = "InstanceId", Selector = "$.Instances[0].InstanceId", Type = "String" }]
      },
      {
        name   = "WaitUntilDBInstanceRunning"
        action = "aws:waitForAwsResourceProperty"
        timeoutSeconds = 900
        inputs = {
          Service          = "ec2"
          Api              = "DescribeInstances"
          InstanceIds      = ["{{LaunchRecoveredDBInstance.InstanceId}}"]
          PropertySelector = "$.Reservations[0].Instances[0].State.Name"
          DesiredValues    = ["running"]
        }
      },
      {
        name   = "AttachRecoveredDBVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "ec2"
          Api        = "AttachVolume"
          Device     = "/dev/sdf"
          InstanceId = "{{LaunchRecoveredDBInstance.InstanceId}}"
          VolumeId   = "{{CreateDBRecoveryVolume.VolumeId}}"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.name}-${var.environment}-recovery-db"
    Environment = var.environment
    ManagedBy   = "brainctl"
  }
}


resource "aws_iam_role" "recovery_drill_scheduler" {
  count = var.enable_recovery_mode && var.recovery_drill_enabled && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  name  = "${var.name}-${var.environment}-drill-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "recovery_drill_scheduler" {
  count = var.enable_recovery_mode && var.recovery_drill_enabled && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  name  = "${var.name}-${var.environment}-drill-scheduler-policy"
  role  = aws_iam_role.recovery_drill_scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:StartAutomationExecution"
      Resource = "*"
    }]
  })
}

data "aws_subnet" "recovery_subnet" {
  count = var.enable_recovery_mode && var.recovery_drill_enabled && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  id    = var.app_recovery_subnet_id
}

resource "aws_scheduler_schedule" "recovery_app_drill" {
  count       = var.enable_recovery_mode && var.recovery_drill_enabled && var.recovery_enable_runbooks && var.recovery_backup_app ? 1 : 0
  name        = "${var.name}-${var.environment}-drill-monthly"
  description = "Dispara DR drill mensal para APP recovery runbook"

  schedule_expression          = var.recovery_drill_schedule_expression
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ssm:startAutomationExecution"
    role_arn = aws_iam_role.recovery_drill_scheduler[0].arn
    input = jsonencode({
      DocumentName = aws_ssm_document.recovery_app_runbook[0].name
      Parameters = {
        AvailabilityZone      = [data.aws_subnet.recovery_subnet[0].availability_zone]
        SubnetId              = [var.app_recovery_subnet_id]
        SecurityGroupId       = [var.app_recovery_security_group_id]
        ImageId               = [var.app_recovery_ami_id]
        InstanceType          = [var.app_recovery_instance_type]
        IamInstanceProfileName = [var.app_recovery_instance_profile_name]
        RegisterToTargetGroup = [tostring(var.recovery_drill_register_to_target_group)]
        TargetGroupArn        = [var.app_recovery_target_group_arn]
      }
    })
  }

  depends_on = [aws_iam_role_policy.recovery_drill_scheduler]
}

data "aws_caller_identity" "current" {}
