package ec2app

import "testing"

func TestSanitizePowerShellUserData(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{name: "plain script", in: "Write-Host 'ok'", want: "Write-Host 'ok'"},
		{name: "wrapped script", in: "<powershell>\nWrite-Host 'ok'\n</powershell>", want: "Write-Host 'ok'"},
		{name: "wrapped mixed case", in: "<PowerShell>Write-Host 'ok'</PowerShell>", want: "Write-Host 'ok'"},
		{name: "empty", in: "", want: ""},
		{name: "multiple wrappers", in: "<powershell>a</powershell>\n<powershell>b</powershell>", wantErr: true},
		{name: "open tag only", in: "<powershell>Write-Host 'ok'", wantErr: true},
		{name: "close tag only", in: "Write-Host 'ok'</powershell>", wantErr: true},
		{name: "wrapper not enclosing whole script", in: "#comment\n<powershell>Write-Host 'ok'</powershell>", wantErr: true},
		{name: "empty wrapped", in: "<powershell>   </powershell>", wantErr: true},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := sanitizePowerShellUserData(tt.in)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil with value %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}
