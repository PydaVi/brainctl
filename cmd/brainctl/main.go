package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/PydaVi/brainctl/internal/config"
	"github.com/PydaVi/brainctl/internal/generator"
	"github.com/PydaVi/brainctl/internal/terraform"
	"github.com/PydaVi/brainctl/internal/workspace"
)

func main() {
	var file string

	root := &cobra.Command{
		Use:   "brainctl",
		Short: "brainctl manages app infra from a declarative YAML",
	}

	// helper pra evitar repetir 30x a mesma pipeline
	prepare := func() (*config.AppConfig, string, *terraform.Runner, error) {
		cfg, err := config.LoadConfig(file)
		if err != nil {
			return nil, "", nil, err
		}
		if err := cfg.Validate(); err != nil {
			return nil, "", nil, err
		}

		wsDir, err := workspace.Prepare(cfg)
		if err != nil {
			return nil, "", nil, err
		}

		if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
			return nil, "", nil, err
		}

		r := terraform.NewRunner(wsDir)
		if err := r.Init(); err != nil {
			return nil, "", nil, err
		}

		return cfg, wsDir, r, nil
	}

	// -------- plan --------
	planCmd := &cobra.Command{
		Use:   "plan",
		Short: "Generate terraform and run terraform init/plan",
		RunE: func(cmd *cobra.Command, args []string) error {
			_, _, r, err := prepare()
			if err != nil {
				return err
			}
			return r.Plan()
		},
	}

	// -------- apply --------
	applyCmd := &cobra.Command{
		Use:   "apply",
		Short: "Generate terraform and run terraform init/apply (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			_, _, r, err := prepare()
			if err != nil {
				return err
			}
			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return r.Apply(autoApprove)
		},
	}
	applyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	// -------- destroy --------
	destroyCmd := &cobra.Command{
		Use:   "destroy",
		Short: "Run terraform destroy for the generated workspace (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			_, _, r, err := prepare()
			if err != nil {
				return err
			}
			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return r.Destroy(autoApprove)
		},
	}
	destroyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	// -------- output --------
	outputCmd := &cobra.Command{
		Use:   "output",
		Short: "Print terraform outputs (json)",
		RunE: func(cmd *cobra.Command, args []string) error {
			_, _, r, err := prepare()
			if err != nil {
				return err
			}

			out, err := r.OutputJSON()
			if err != nil {
				return err
			}
			fmt.Println(string(out))
			return nil
		},
	}

	// -------- status --------
	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show workspace/backend/state status and pretty outputs (if present)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, wsDir, r, err := prepare()
			if err != nil {
				return err
			}

			fmt.Println("== brainctl status ==")
			fmt.Printf("App: %s (%s)\n", cfg.App.Name, cfg.App.Environment)
			fmt.Printf("Region: %s\n", cfg.App.Region)
			fmt.Printf("Workspace: %s\n", wsDir)
			fmt.Printf("Backend bucket: %s\n", "brainctl-terraform-states")
			fmt.Printf("Backend key: %s/%s/terraform.tfstate\n", cfg.App.Name, cfg.App.Environment)

			present, _ := r.StatePull()
			if !present {
				fmt.Println("State: missing/unreachable")
				return nil
			}
			fmt.Println("State: present")

			outRaw, err := r.OutputJSON()
			if err != nil {
				fmt.Println("Outputs: unavailable (terraform output failed)")
				return nil
			}

			outs, err := terraform.ParseOutputs(outRaw)
			if err != nil {
				fmt.Println("Outputs: unreadable (failed to parse json)")
				fmt.Println(string(outRaw))
				return nil
			}

			fmt.Println()
			fmt.Println("Resources:")

			// APP
			fmt.Println("  APP")
			fmt.Printf("    instance_id: %s\n", nz(outs["instance_id"]))
			fmt.Printf("    private_ip : %s\n", nz(outs["private_ip"]))
			fmt.Printf("    public_ip  : %s\n", nz(outs["public_ip"]))
			fmt.Printf("    sg         : %s (%s)\n", nz(outs["security_group_name"]), nz(outs["security_group_id"]))

			// DB (best effort)
			if _, ok := outs["db_instance_id"]; ok {
				fmt.Println()
				fmt.Println("  DB")
				fmt.Printf("    instance_id: %s\n", nz(outs["db_instance_id"]))
				fmt.Printf("    private_ip : %s\n", nz(outs["db_private_ip"]))
				fmt.Printf("    sg         : %s (%s)\n", nz(outs["db_security_group_name"]), nz(outs["db_security_group_id"]))
			}

			return nil
		},
	}

	// flags (todos usam o mesmo -f)
	root.PersistentFlags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")

	root.AddCommand(planCmd, applyCmd, destroyCmd, statusCmd, outputCmd)

	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func nz(s string) string {
	if s == "" {
		return "(none)"
	}
	return s
}
