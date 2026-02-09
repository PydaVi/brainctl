package outputs

import (
	"encoding/json"
	"fmt"
)

type tfOutputItem struct {
	Value any `json:"value"`
}

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

func PrintPrettyStatus(v map[string]any) {
	fmt.Println("Resources:")

	// APP
	fmt.Println("  APP")
	fmt.Printf("    instance_id: %s\n", asString(v["instance_id"], "(none)"))
	fmt.Printf("    private_ip : %s\n", asString(v["private_ip"], "(none)"))
	fmt.Printf("    public_ip  : %s\n", asString(v["public_ip"], "(none)"))

	sgName := asString(v["security_group_name"], "(none)")
	sgID := asString(v["security_group_id"], "(none)")
	fmt.Printf("    sg         : %s (%s)\n", sgName, sgID)
	fmt.Println()

	// DB (se existir)
	dbID, hasDB := v["db_instance_id"]
	if hasDB && asString(dbID, "") != "" {
		fmt.Println("  DB")
		fmt.Printf("    instance_id: %s\n", asString(v["db_instance_id"], "(none)"))
		fmt.Printf("    private_ip : %s\n", asString(v["db_private_ip"], "(none)"))

		dbSgName := asString(v["db_security_group_name"], "(none)")
		dbSgID := asString(v["db_security_group_id"], "(none)")
		fmt.Printf("    sg         : %s (%s)\n", dbSgName, dbSgID)
		fmt.Println()
	}

	// ALB (se existir)
	albDNS, hasALB := v["alb_dns_name"]
	if hasALB && asString(albDNS, "") != "" {
		fmt.Println("  ALB")
		fmt.Printf("    dns_name   : %s\n", asString(v["alb_dns_name"], "(none)"))
		fmt.Println()
	}
}

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
		// terraform pode devolver number/bool em alguns outputs
		s := fmt.Sprintf("%v", t)
		if s == "" {
			return fallback
		}
		return s
	}
}
