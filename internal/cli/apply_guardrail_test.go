package cli

import "testing"

func TestDetectModifiedInstances(t *testing.T) {
	t.Parallel()

	raw := []byte(`{
  "resource_changes": [
    {"address":"aws_instance.app[0]","type":"aws_instance","change":{"actions":["update"]}},
    {"address":"aws_db_instance.db[0]","type":"aws_db_instance","change":{"actions":["delete","create"]}},
    {"address":"aws_security_group.app_sg","type":"aws_security_group","change":{"actions":["update"]}}
  ]
}`)

	got, err := detectModifiedInstances(raw)
	if err != nil {
		t.Fatalf("detectModifiedInstances failed: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("expected 2 resources, got %d (%v)", len(got), got)
	}
}

func TestDetectModifiedInstances_NoInstanceChanges(t *testing.T) {
	t.Parallel()

	raw := []byte(`{"resource_changes":[{"address":"aws_lb.app","type":"aws_lb","change":{"actions":["update"]}}]}`)
	got, err := detectModifiedInstances(raw)
	if err != nil {
		t.Fatalf("detectModifiedInstances failed: %v", err)
	}
	if len(got) != 0 {
		t.Fatalf("expected 0 resources, got %d", len(got))
	}
}

func TestConfirmInstanceModify_AutoApprovedByEnv(t *testing.T) {
	t.Setenv(guardrailApprovalEnv, "SIM")

	ok, err := confirmInstanceModify([]string{"aws_instance.app[0]"})
	if err != nil {
		t.Fatalf("confirmInstanceModify returned error: %v", err)
	}
	if !ok {
		t.Fatal("expected automatic approval to return true")
	}
}
