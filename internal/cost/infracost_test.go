package cost

import "testing"

func TestParseInfracostJSONInfraBase(t *testing.T) {
	raw := []byte(`{
  "projects": [
    {
      "breakdown": {
        "resources": [
          {"resourceType":"aws_instance","hourlyCost":"0.0416","monthlyCost":"30.37"},
          {"resourceType":"aws_ebs_volume","hourlyCost":"0","monthlyCost":"8.00"},
          {"resourceType":"aws_db_instance","hourlyCost":"0.0670","monthlyCost":"48.91"},
          {"resourceType":"aws_lb","hourlyCost":"0.0225","monthlyCost":"16.43"},
          {"resourceType":"aws_nat_gateway","hourlyCost":"0.045","monthlyCost":"32.85"},
          {"resourceType":"aws_eip","hourlyCost":"0.005","monthlyCost":"3.65"},
          {"resourceType":"aws_vpc_endpoint","hourlyCost":"0.010","monthlyCost":"7.30"},
          {"resourceType":"aws_cloudwatch_log_group","hourlyCost":"0","monthlyCost":"1.20"},
          {"resourceType":"aws_ssm_association","hourlyCost":"0","monthlyCost":"0.25"},
          {"resourceType":"aws_security_group","hourlyCost":"0","monthlyCost":"0"}
        ]
      }
    }
  ]
}`)

	report, err := ParseInfracostJSON(raw)
	if err != nil {
		t.Fatalf("ParseInfracostJSON failed: %v", err)
	}

	if len(report.Services) != 9 {
		t.Fatalf("expected 9 services, got %d", len(report.Services))
	}

	if report.TotalHourly <= 0 {
		t.Fatalf("expected positive hourly total, got %.4f", report.TotalHourly)
	}
	if report.TotalMonthly <= 0 {
		t.Fatalf("expected positive monthly total, got %.2f", report.TotalMonthly)
	}
}

func TestParseMoney(t *testing.T) {
	if got := parseMoney("<0.01"); got != 0.01 {
		t.Fatalf("expected 0.01, got %.4f", got)
	}
}

func TestParseInfracostJSONWithPrefixedLogs(t *testing.T) {
	raw := []byte(`INFO using cached prices
{
  "projects": [
    {
      "breakdown": {
        "resources": [
          {"resourceType":"aws_instance","hourlyCost":"0.0416","monthlyCost":"30.37"}
        ]
      }
    }
  ]
}`)

	report, err := ParseInfracostJSON(raw)
	if err != nil {
		t.Fatalf("ParseInfracostJSON failed with prefixed logs: %v", err)
	}
	if len(report.Services) != 1 {
		t.Fatalf("expected 1 service, got %d", len(report.Services))
	}
}
