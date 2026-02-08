package terraform

import (
	"encoding/json"
	"fmt"
	"sort"
)

type tfOutput struct {
	Sensitive bool            `json:"sensitive"`
	Type      any             `json:"type"`
	Value     json.RawMessage `json:"value"`
}

// ParseOutputs pega o JSON do `terraform output -json` e devolve map[string]string (value "printável")
func ParseOutputs(raw []byte) (map[string]string, error) {
	var m map[string]tfOutput
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("parse terraform outputs json: %w", err)
	}

	out := make(map[string]string, len(m))
	for k, v := range m {
		// maioria dos seus outputs é string; vamos tentar string primeiro
		var s string
		if err := json.Unmarshal(v.Value, &s); err == nil {
			out[k] = s
			continue
		}

		// fallback: imprime o JSON compacto (pra não quebrar se tiver list/map no futuro)
		out[k] = string(v.Value)
	}

	return out, nil
}

func KeysSorted(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
