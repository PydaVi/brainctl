package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/PydaVi/brainctl/internal/config"
	"github.com/PydaVi/brainctl/internal/generator"
	"github.com/PydaVi/brainctl/internal/outputs"
	"github.com/PydaVi/brainctl/internal/terraform"
	"github.com/PydaVi/brainctl/internal/workspace"
)

const (
	backendBucket = "brainctl-terraform-states"
)

func main() {
	var file string
	var stackDir string
	var overridesFile string

	root := &cobra.Command{
		Use:   "brainctl",
		Short: "brainctl manages app infra from a declarative YAML",
	}

	planCmd := &cobra.Command{
		Use:   "plan",
		Short: "Generate terraform and run terraform init/plan",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := loadRuntimeConfig(stackDir, file, overridesFile)
			if err != nil {
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
	applyCommonFlags(planCmd, &file, &stackDir, &overridesFile)

	applyCmd := &cobra.Command{
		Use:   "apply",
		Short: "Generate terraform and run terraform init/apply (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := loadRuntimeConfig(stackDir, file, overridesFile)
			if err != nil {
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
	applyCommonFlags(applyCmd, &file, &stackDir, &overridesFile)
	applyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	destroyCmd := &cobra.Command{
		Use:   "destroy",
		Short: "Run terraform destroy for the generated workspace (auto-approve by default)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := loadRuntimeConfig(stackDir, file, overridesFile)
			if err != nil {
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
	applyCommonFlags(destroyCmd, &file, &stackDir, &overridesFile)
	destroyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show workspace/backend/state and key resource info (pretty)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := loadRuntimeConfig(stackDir, file, overridesFile)
			if err != nil {
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
			fmt.Printf("Stack dir: %s\n", stackDir)
			fmt.Printf("Workspace: %s\n", wsDir)
			fmt.Printf("Backend bucket: %s\n", backendBucket)
			fmt.Printf("Backend key: %s\n", backendKey)
			if cfg.AppScaling.Enabled {
				fmt.Printf("App scaling: enabled (min=%d desired=%d max=%d cpu_target=%.1f)\n", cfg.AppScaling.MinSize, cfg.AppScaling.DesiredCapacity, cfg.AppScaling.MaxSize, cfg.AppScaling.CPUTarget)
			} else {
				fmt.Println("App scaling: disabled")
			}
			if cfg.EC2.IMDSv2Required {
				fmt.Println("IMDSv2: required")
			} else {
				fmt.Println("IMDSv2: optional")
			}
			if cfg.Observability.Enabled != nil && *cfg.Observability.Enabled {
				fmt.Printf("Observability: enabled (cpu_high_threshold=%d)\n", cfg.Observability.CPUHighThreshold)
			} else {
				fmt.Println("Observability: disabled")
			}
			if len(cfg.RuntimeOverrides.AppExtraIngress)+len(cfg.RuntimeOverrides.DBExtraIngress)+len(cfg.RuntimeOverrides.ALBExtraIngress) > 0 {
				fmt.Printf("Overrides: app_extra_ingress_rules=%d db_extra_ingress_rules=%d alb_extra_ingress_rules=%d\n",
					len(cfg.RuntimeOverrides.AppExtraIngress), len(cfg.RuntimeOverrides.DBExtraIngress), len(cfg.RuntimeOverrides.ALBExtraIngress))
			}
			if cfg.Recovery.Enabled {
				fmt.Printf("Recovery: enabled (time_utc=%s retention_days=%d backup_app=%t backup_db=%t runbooks=%t)\n",
					cfg.Recovery.SnapshotTimeUTC, cfg.Recovery.RetentionDays,
					cfg.Recovery.BackupApp != nil && *cfg.Recovery.BackupApp,
					cfg.Recovery.BackupDB != nil && *cfg.Recovery.BackupDB,
					cfg.Recovery.EnableRunbooks != nil && *cfg.Recovery.EnableRunbooks)
			} else {
				fmt.Println("Recovery: disabled")
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
	applyCommonFlags(statusCmd, &file, &stackDir, &overridesFile)

	outputCmd := &cobra.Command{
		Use:   "output",
		Short: "Print terraform outputs (json)",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := loadRuntimeConfig(stackDir, file, overridesFile)
			if err != nil {
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
	applyCommonFlags(outputCmd, &file, &stackDir, &overridesFile)

	root.AddCommand(planCmd, applyCmd, destroyCmd, statusCmd, outputCmd)
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func applyCommonFlags(cmd *cobra.Command, file *string, stackDir *string, overridesFile *string) {
	cmd.Flags().StringVarP(file, "file", "f", "app.yaml", "Path to app.yaml (relative to --stack-dir when not absolute)")
	cmd.Flags().StringVar(stackDir, "stack-dir", ".", "Stack directory (ex: stacks/dev)")
	cmd.Flags().StringVar(overridesFile, "overrides", "overrides.yaml", "Path to overrides file (relative to --stack-dir). Empty disables overrides")
}

func loadRuntimeConfig(stackDir, file, overridesFile string) (*config.AppConfig, error) {
	cfgPath := file
	if !filepath.IsAbs(cfgPath) {
		cfgPath = filepath.Join(stackDir, file)
	}

	cfg, err := config.LoadConfig(cfgPath)
	if err != nil {
		return nil, err
	}

	if overridesFile != "" {
		oPath := overridesFile
		if !filepath.IsAbs(oPath) {
			oPath = filepath.Join(stackDir, overridesFile)
		}
		if _, statErr := os.Stat(oPath); statErr == nil {
			if err := config.ApplyOverridesFile(cfg, oPath); err != nil {
				return nil, err
			}
		} else if !errors.Is(statErr, os.ErrNotExist) {
			return nil, statErr
		}
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}
