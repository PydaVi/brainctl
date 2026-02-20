package cost

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"os/exec"
	"sort"
	"strconv"
	"strings"
)

const monthlyHours = 730.0

// ServiceCost representa custo agregado por categoria de serviço.
type ServiceCost struct {
	Service string  `json:"service"`
	Hourly  float64 `json:"hourly"`
	Monthly float64 `json:"monthly"`
}

// Report é o resultado consolidado da estimativa.
type Report struct {
	Services     []ServiceCost `json:"services"`
	TotalHourly  float64       `json:"total_hourly"`
	TotalMonthly float64       `json:"total_monthly"`
}

type infracostOutput struct {
	Projects []struct {
		Breakdown struct {
			Resources []infracostResource `json:"resources"`
		} `json:"breakdown"`
	} `json:"projects"`
}

type infracostResource struct {
	ResourceType   string                   `json:"resourceType"`
	MonthlyCost    string                   `json:"monthlyCost"`
	HourlyCost     string                   `json:"hourlyCost"`
	CostComponents []infracostCostComponent `json:"costComponents"`
}

type infracostCostComponent struct {
	MonthlyCost string `json:"monthlyCost"`
	HourlyCost  string `json:"hourlyCost"`
}

// EstimateInfraBase executa Infracost e gera um report resumido para custos base.
func EstimateInfraBase(workspaceDir string) (*Report, error) {
	cmd := exec.Command("infracost", "breakdown", "--path", workspaceDir, "--format", "json", "--no-color")

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("infracost breakdown failed: %w\n%s", err, strings.TrimSpace(stderr.String()))
	}

	report, err := ParseInfracostJSON(stdout.Bytes())
	if err != nil {
		return nil, fmt.Errorf("%w\nraw_stdout=%q\nraw_stderr=%q", err, strings.TrimSpace(stdout.String()), strings.TrimSpace(stderr.String()))
	}
	return report, nil
}

func extractJSONObject(raw []byte) []byte {
	raw = bytes.TrimSpace(raw)
	start := bytes.IndexByte(raw, '{')
	end := bytes.LastIndexByte(raw, '}')
	if start >= 0 && end > start {
		return raw[start : end+1]
	}
	return raw
}

// ParseInfracostJSON agrega por serviço os recursos da fase 1 (infra base).
func ParseInfracostJSON(raw []byte) (*Report, error) {
	var payload infracostOutput
	if err := json.Unmarshal(extractJSONObject(raw), &payload); err != nil {
		return nil, fmt.Errorf("parse infracost json: %w", err)
	}

	agg := map[string]*ServiceCost{}
	for _, p := range payload.Projects {
		for _, r := range p.Breakdown.Resources {
			hourly := parseMoney(r.HourlyCost)
			monthly := parseMoney(r.MonthlyCost)

			if hourly == 0 || monthly == 0 {
				ch, cm := sumComponents(r.CostComponents)
				if hourly == 0 {
					hourly = ch
				}
				if monthly == 0 {
					monthly = cm
				}
			}
			if hourly == 0 && monthly > 0 {
				hourly = monthly / monthlyHours
			}
			if monthly == 0 && hourly > 0 {
				monthly = hourly * monthlyHours
			}

			service, ok := classifyResourceType(r.ResourceType)
			if !ok {
				if hourly == 0 && monthly == 0 {
					continue
				}
				service = fmt.Sprintf("Other (%s)", r.ResourceType)
			}

			entry, exists := agg[service]
			if !exists {
				entry = &ServiceCost{Service: service}
				agg[service] = entry
			}
			entry.Hourly += hourly
			entry.Monthly += monthly
		}
	}

	services := make([]ServiceCost, 0, len(agg))
	var totalH, totalM float64
	for _, v := range agg {
		v.Hourly = round4(v.Hourly)
		v.Monthly = round2(v.Monthly)
		totalH += v.Hourly
		totalM += v.Monthly
		services = append(services, *v)
	}
	sort.Slice(services, func(i, j int) bool { return services[i].Service < services[j].Service })

	return &Report{
		Services:     services,
		TotalHourly:  round4(totalH),
		TotalMonthly: round2(totalM),
	}, nil
}

func classifyResourceType(resourceType string) (string, bool) {
	switch resourceType {
	case "aws_instance":
		return "EC2", true
	case "aws_ebs_volume":
		return "EBS", true
	case "aws_db_instance":
		return "RDS", true
	case "aws_lb":
		return "ALB", true
	case "aws_nat_gateway":
		return "NAT Gateway", true
	case "aws_eip":
		return "EIP", true
	case "aws_vpc_endpoint":
		return "VPC Endpoint", true
	case "aws_cloudwatch_log_group":
		return "CloudWatch Logs", true
	case "aws_sns_topic":
		return "SNS", true
	default:
		return "", false
	}
}

func sumComponents(components []infracostCostComponent) (hourly float64, monthly float64) {
	for _, c := range components {
		hourly += parseMoney(c.HourlyCost)
		monthly += parseMoney(c.MonthlyCost)
	}
	return hourly, monthly
}

func parseMoney(raw string) float64 {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0
	}
	raw = strings.TrimPrefix(raw, "$")
	raw = strings.TrimPrefix(raw, "<")
	raw = strings.ReplaceAll(raw, ",", "")

	v, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return 0
	}
	return v
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

func round4(v float64) float64 {
	return math.Round(v*10000) / 10000
}
