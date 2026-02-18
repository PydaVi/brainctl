package blueprints

import "testing"

func TestResolve_K8sWorkers(t *testing.T) {
	t.Parallel()

	bp, err := Resolve("k8s-workers", "v1")
	if err != nil {
		t.Fatalf("resolve k8s-workers: %v", err)
	}
	if bp.Type != "k8s-workers" {
		t.Fatalf("unexpected type: %s", bp.Type)
	}
}
