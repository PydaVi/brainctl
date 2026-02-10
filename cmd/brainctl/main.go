package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/PydaVi/brainctl/internal/config"
	"github.com/PydaVi/brainctl/internal/generator"
	"github.com/PydaVi/brainctl/internal/outputs"
	"github.com/PydaVi/brainctl/internal/terraform"
	"github.com/PydaVi/brainctl/internal/workspace"
)

const (
	// backendBucket é o bucket S3 usado para state remoto do Terraform.
	backendBucket = "brainctl-terraform-states"
)

// main define todos os subcomandos da CLI.
// Pipeline base de cada comando:
// 1) LoadConfig + Validate
// 2) Prepare workspace
// 3) Generate Terraform
// 4) Executar operação do Terraform
func main() {
	var file string

	root := &cobra.Command{
		Use:   "brainctl",
		Short: "brainctl manages app infra from a declarative YAML",
	}

	planCmd := &cobra.Command{
		Use:   "plan",
		Short: "Generate terraform and run terraform init/plan",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.LoadConfig(file)
			if err != nil {
				return err
			}
			if err := cfg.Validate(); err != nil {
				return err
			}

			wsDir, err := workspace.Prepare(cfg)
			if err != nil {
				return err
			}

			if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
				return err
			}

			r := terraform.NewRunner(wsDir)
			if err := r.Init(); err != nil {
				return err
			}

			return r.Plan()
		},
	}
	planCmd.Flags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")

	applyCmd := &cobra.Command{
		Use:   "apply",
		Short: "Generate terraform and run terraform init/apply (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.LoadConfig(file)
			if err != nil {
				return err
			}
			if err := cfg.Validate(); err != nil {
				return err
			}

			wsDir, err := workspace.Prepare(cfg)
			if err != nil {
				return err
			}

			if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
				return err
			}

			r := terraform.NewRunner(wsDir)
			if err := r.Init(); err != nil {
				return err
			}

			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return r.Apply(autoApprove)
		},
	}
	applyCmd.Flags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")
	applyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	destroyCmd := &cobra.Command{
		Use:   "destroy",
		Short: "Run terraform destroy for the generated workspace (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.LoadConfig(file)
			if err != nil {
				return err
			}
			if err := cfg.Validate(); err != nil {
				return err
			}

			wsDir, err := workspace.Prepare(cfg)
			if err != nil {
				return err
			}

			if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
				return err
			}

			r := terraform.NewRunner(wsDir)
			if err := r.Init(); err != nil {
				return err
			}

			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return r.Destroy(autoApprove)
		},
	}
	destroyCmd.Flags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")
	destroyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show workspace/backend/state and key resource info (pretty)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.LoadConfig(file)
			if err != nil {
				return err
			}
			if err := cfg.Validate(); err != nil {
				return err
			}

			wsDir, err := workspace.Prepare(cfg)
			if err != nil {
				return err
			}

			if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
				return err
			}

			r := terraform.NewRunner(wsDir)
			if err := r.Init(); err != nil {
				return err
			}

			backendKey := fmt.Sprintf("%s/%s/terraform.tfstate", cfg.App.Name, cfg.App.Environment)

			fmt.Println("== brainctl status ==")
			fmt.Printf("App: %s (%s)\n", cfg.App.Name, cfg.App.Environment)
			fmt.Printf("Region: %s\n", cfg.App.Region)
			fmt.Printf("Workspace: %s\n", wsDir)
			fmt.Printf("Backend bucket: %s\n", backendBucket)
			fmt.Printf("Backend key: %s\n", backendKey)
			if cfg.Observability.Enabled != nil && *cfg.Observability.Enabled {
				fmt.Printf("Observability: enabled (cpu_high_threshold=%d)\n", cfg.Observability.CPUHighThreshold)
			} else {
				fmt.Println("Observability: disabled")
			}

			present, _ := r.StatePull()
			if !present {
				fmt.Println("State: missing/unreachable")
				return nil
			}
			fmt.Println("State: present")
			fmt.Println()

			raw, err := r.OutputJSON()
			if err != nil {
				fmt.Println("Outputs: unavailable (terraform output failed)")
				return nil
			}

			vals, err := outputs.ParseTerraformOutputJSON(raw)
			if err != nil {
				return fmt.Errorf("parse outputs: %w", err)
			}

			outputs.PrintPrettyStatus(vals)
			return nil
		},
	}
	statusCmd.Flags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")

	outputCmd := &cobra.Command{
		Use:   "output",
		Short: "Print terraform outputs (json)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.LoadConfig(file)
			if err != nil {
				return err
			}
			if err := cfg.Validate(); err != nil {
				return err
			}

			wsDir, err := workspace.Prepare(cfg)
			if err != nil {
				return err
			}

			if err := generator.GenerateEC2App(wsDir, cfg); err != nil {
				return err
			}

			r := terraform.NewRunner(wsDir)
			if err := r.Init(); err != nil {
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
	outputCmd.Flags().StringVarP(&file, "file", "f", "app.yaml", "Path to app.yaml")

	root.AddCommand(planCmd, applyCmd, destroyCmd, statusCmd, outputCmd)

	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}