package outputs

import (
	"encoding/json"
	"fmt"
)

// tfOutputItem representa o formato padrão do `terraform output -json`.
type tfOutputItem struct {
	Value any `json:"value"`
}

// ParseTerraformOutputJSON simplifica o output para mapa chave->valor.
func ParseTerraformOutputJSON(raw []byte) (map[string]any, error) {
	m := map[string]tfOutputItem{}
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}

	out := make(map[string]any, len(m))
	for k, v := range m {
		out[k] = v.Value
	}
	return out, nil
}

// PrintPrettyStatus renderiza um resumo humano amigável para o comando status.
func PrintPrettyStatus(v map[string]any) {
	fmt.Println("Resources:")

	fmt.Println("  APP")
	if asgName := asString(v["app_asg_name"], ""); asgName != "" {
		fmt.Printf("    asg_name   : %s\n", asgName)
		fmt.Printf("    asg_size   : min=%s desired=%s max=%s\n", asString(v["app_asg_min_size"], "?"), asString(v["app_asg_desired_capacity"], "?"), asString(v["app_asg_max_size"], "?"))
	} else {
		fmt.Printf("    instance_id: %s\n", asString(v["instance_id"], "(none)"))
		fmt.Printf("    private_ip : %s\n", asString(v["private_ip"], "(none)"))
		fmt.Printf("    public_ip  : %s\n", asString(v["public_ip"], "(none)"))
	}
	fmt.Printf("    sg         : %s (%s)\n", asString(v["security_group_name"], "(none)"), asString(v["security_group_id"], "(none)"))
	fmt.Println()

	if dbID := asString(v["db_instance_id"], ""); dbID != "" {
		fmt.Println("  DB")
		fmt.Printf("    instance_id: %s\n", dbID)
		fmt.Printf("    private_ip : %s\n", asString(v["db_private_ip"], "(none)"))
		fmt.Printf("    sg         : %s (%s)\n", asString(v["db_security_group_name"], "(none)"), asString(v["db_security_group_id"], "(none)"))
		fmt.Println()
	}

	if albDNS := asString(v["alb_dns_name"], ""); albDNS != "" {
		fmt.Println("  ALB")
		fmt.Printf("    dns_name   : %s\n", albDNS)
		fmt.Println()
	}

	appDash := asString(v["observability_app_dashboard_name"], "")
	dbDash := asString(v["observability_db_dashboard_name"], "")
	if appDash != "" || dbDash != "" {
		fmt.Println("  OBSERVABILITY")
		if appDash != "" {
			fmt.Printf("    app_dash   : %s\n", appDash)
			fmt.Printf("    app_url    : %s\n", asString(v["observability_app_dashboard_url"], "(none)"))
		}
		if dbDash != "" {
			fmt.Printf("    db_dash    : %s\n", dbDash)
			fmt.Printf("    db_url     : %s\n", asString(v["observability_db_dashboard_url"], "(none)"))
		}

		snsTopic := asString(v["observability_sns_topic_arn"], "")
		email := asString(v["observability_alert_email"], "")
		if snsTopic != "" {
			fmt.Printf("    sns_topic  : %s\n", snsTopic)
			fmt.Printf("    alert_email: %s\n", email)
		}
		fmt.Printf("    log_group  : %s\n", asString(v["observability_log_group_name"], "(none)"))
		fmt.Printf("    ssm_profile: %s\n", asString(v["observability_ssm_profile_name"], "(none)"))

		alarmNames := asStringSlice(v["observability_alarm_names"])
		if len(alarmNames) == 0 {
			fmt.Println("    alarms     : (none)")
		} else {
			fmt.Println("    alarms:")
			for _, name := range alarmNames {
				fmt.Printf("      - %s\n", name)
			}
		}
		fmt.Println()
	}
	recoveryEnabled := asString(v["recovery_enabled"], "")
	if recoveryEnabled == "true" {
		fmt.Println("  RECOVERY")
		fmt.Printf("    snapshot_utc : %s\n", asString(v["recovery_snapshot_time_utc"], "(none)"))
		fmt.Printf("    retention    : %s days\n", asString(v["recovery_retention_days"], "(none)"))
		fmt.Printf("    app_policy   : %s\n", asString(v["recovery_app_policy_id"], "(none)"))
		fmt.Printf("    db_policy    : %s\n", asString(v["recovery_db_policy_id"], "(none)"))
		fmt.Printf("    app_runbook  : %s\n", asString(v["recovery_app_runbook_name"], "(none)"))
		fmt.Printf("    db_runbook   : %s\n", asString(v["recovery_db_runbook_name"], "(none)"))
		fmt.Println()
	}

}

// asString converte valores genéricos em string com fallback.
func asString(x any, fallback string) string {
	if x == nil {
		return fallback
	}
	switch t := x.(type) {
	case string:
		if t == "" {
			return fallback
		}
		return t
	default:
		s := fmt.Sprintf("%v", t)
		if s == "" {
			return fallback
		}
		return s
	}
}

// asStringSlice converte um array genérico para []string ignorando vazios.
func asStringSlice(x any) []string {
	vals, ok := x.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(vals))
	for _, item := range vals {
		s := asString(item, "")
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}
