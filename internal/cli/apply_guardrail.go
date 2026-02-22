package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

const guardrailApprovalEnv = "BRAINCTL_INSTANCE_MODIFY_APPROVED"

type tfPlan struct {
	ResourceChanges []tfPlanResourceChange `json:"resource_changes"`
}

type tfPlanResourceChange struct {
	Address string `json:"address"`
	Type    string `json:"type"`
	Change  struct {
		Actions []string `json:"actions"`
	} `json:"change"`
}

func detectModifiedInstances(planJSON []byte) ([]string, error) {
	var p tfPlan
	if err := json.Unmarshal(planJSON, &p); err != nil {
		return nil, err
	}

	var out []string
	for _, rc := range p.ResourceChanges {
		if rc.Type != "aws_instance" && rc.Type != "aws_db_instance" {
			continue
		}
		if containsAction(rc.Change.Actions, "update") || isReplaceAction(rc.Change.Actions) {
			out = append(out, rc.Address)
		}
	}
	return out, nil
}

func containsAction(actions []string, target string) bool {
	for _, a := range actions {
		if a == target {
			return true
		}
	}
	return false
}

func isReplaceAction(actions []string) bool {
	if len(actions) != 2 {
		return false
	}
	return (actions[0] == "delete" && actions[1] == "create") || (actions[0] == "create" && actions[1] == "delete")
}

func confirmInstanceModify(resources []string) (bool, error) {
	if isApprovedValue(os.Getenv(guardrailApprovalEnv)) {
		fmt.Printf("[guardrail] Aprovação automática recebida via variável de ambiente %s.\n", guardrailApprovalEnv)
		return true, nil
	}

	fmt.Println("\n[guardrail] Foram detectadas alterações em instâncias:")
	for _, r := range resources {
		fmt.Printf("  - %s\n", r)
	}
	fmt.Println("[guardrail] Essas mudanças podem causar reinício/substituição de instância.")

	if !isInteractiveInput() {
		return false, fmt.Errorf("guardrail requer confirmação manual, mas stdin não é interativo; execute com --force-instance-modify ou defina %s=SIM", guardrailApprovalEnv)
	}

	fmt.Print("[guardrail] Digite 'SIM' para continuar: ")

	reader := bufio.NewReader(os.Stdin)
	line, err := reader.ReadString('\n')
	if err != nil {
		return false, err
	}
	return strings.EqualFold(strings.TrimSpace(line), "SIM"), nil
}

func isApprovedValue(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "sim", "true", "1", "yes", "y":
		return true
	default:
		return false
	}
}

func isInteractiveInput() bool {
	info, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}
