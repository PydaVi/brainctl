package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/PydaVi/brainctl/internal/blueprints"
	"github.com/PydaVi/brainctl/internal/outputs"
	"github.com/PydaVi/brainctl/internal/terraform"
)

const (
	backendBucket = "brainctl-terraform-states"
)

type runtimeContext struct {
	Config *RuntimeConfig
	Runner *terraform.Runner
	WSDir  string
}

type commandRunner func(cmd *cobra.Command, args []string, ctx *runtimeContext) error

func NewRootCommand() *cobra.Command {
	var opts RuntimeOptions

	root := &cobra.Command{
		Use:   "brainctl",
		Short: "brainctl manages app infra from a declarative YAML",
	}

	planCmd := &cobra.Command{
		Use:   "plan",
		Short: "Generate terraform and run terraform init/plan",
		RunE:  withRuntime(opts, true, func(cmd *cobra.Command, args []string, ctx *runtimeContext) error { return ctx.Runner.Plan() }),
	}
	applyCommonFlags(planCmd, &opts)

	applyCmd := &cobra.Command{
		Use:   "apply",
		Short: "Generate terraform and run terraform init/apply (auto-approve by default)",
		RunE: withRuntime(opts, true, func(cmd *cobra.Command, args []string, ctx *runtimeContext) error {
			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return ctx.Runner.Apply(autoApprove)
		}),
	}
	applyCommonFlags(applyCmd, &opts)
	applyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	destroyCmd := &cobra.Command{
		Use:   "destroy",
		Short: "Run terraform destroy for the generated workspace (auto-approve by default)",
		RunE: withRuntime(opts, true, func(cmd *cobra.Command, args []string, ctx *runtimeContext) error {
			autoApprove, _ := cmd.Flags().GetBool("auto-approve")
			return ctx.Runner.Destroy(autoApprove)
		}),
	}
	applyCommonFlags(destroyCmd, &opts)
	destroyCmd.Flags().Bool("auto-approve", true, "Skip interactive approval (default: true)")

	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show workspace/backend/state and key resource info (pretty)",
		RunE:  withRuntime(opts, true, statusRun),
	}
	applyCommonFlags(statusCmd, &opts)

	outputCmd := &cobra.Command{
		Use:   "output",
		Short: "Print terraform outputs (json)",
		RunE: withRuntime(opts, true, func(cmd *cobra.Command, args []string, ctx *runtimeContext) error {
			out, err := ctx.Runner.OutputJSON()
			if err != nil {
				return err
			}
			fmt.Println(string(out))
			return nil
		}),
	}
	applyCommonFlags(outputCmd, &opts)

	blueprintsCmd := &cobra.Command{
		Use:   "blueprints",
		Short: "List available workload blueprints",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("== available blueprints ==")
			for _, b := range blueprints.List() {
				fmt.Printf("- %s@%s: %s\n", b.Type, b.Version, b.Description)
			}
		},
	}

	root.AddCommand(planCmd, applyCmd, destroyCmd, statusCmd, outputCmd, blueprintsCmd)
	return root
}

func withRuntime(opts RuntimeOptions, initTerraform bool, run commandRunner) func(cmd *cobra.Command, args []string) error {
	return func(cmd *cobra.Command, args []string) error {
		runtimeOpts := optionsFromFlags(cmd)
		cfg, err := LoadRuntimeConfig(runtimeOpts)
		if err != nil {
			return err
		}

		wsDir, err := cfg.PrepareWorkspace()
		if err != nil {
			return err
		}

		r := terraform.NewRunner(wsDir)
		if initTerraform {
			if err := r.Init(); err != nil {
				return err
			}
		}

		ctx := &runtimeContext{Config: cfg, Runner: r, WSDir: wsDir}
		return run(cmd, args, ctx)
	}
}

func applyCommonFlags(cmd *cobra.Command, opts *RuntimeOptions) {
	cmd.Flags().StringVarP(&opts.File, "file", "f", "app.yaml", "Path to app.yaml (relative to --stack-dir when not absolute)")
	cmd.Flags().StringVar(&opts.StackDir, "stack-dir", ".", "Stack directory (ex: stacks/dev)")
	cmd.Flags().StringVar(&opts.OverridesFile, "overrides", "overrides.yaml", "Path to overrides file (relative to --stack-dir). Empty disables overrides")
}

func optionsFromFlags(cmd *cobra.Command) RuntimeOptions {
	file, _ := cmd.Flags().GetString("file")
	stackDir, _ := cmd.Flags().GetString("stack-dir")
	overrides, _ := cmd.Flags().GetString("overrides")
	return RuntimeOptions{
		File:          file,
		StackDir:      stackDir,
		OverridesFile: overrides,
	}
}

func statusRun(cmd *cobra.Command, args []string, ctx *runtimeContext) error {
	cfg := ctx.Config.App
	backendKey := fmt.Sprintf("%s/%s/terraform.tfstate", cfg.App.Name, cfg.App.Environment)

	fmt.Println("== brainctl status ==")
	fmt.Printf("App: %s (%s)\n", cfg.App.Name, cfg.App.Environment)
	fmt.Printf("Workload: %s@%s\n", cfg.Workload.Type, cfg.Workload.Version)
	fmt.Printf("Region: %s\n", cfg.App.Region)
	fmt.Printf("Stack dir: %s\n", ctx.Config.Opts.StackDir)
	fmt.Printf("Workspace: %s\n", ctx.WSDir)
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

	present, _ := ctx.Runner.StatePull()
	if !present {
		fmt.Println("State: missing/unreachable")
		return nil
	}
	fmt.Println("State: present")
	fmt.Println()

	raw, err := ctx.Runner.OutputJSON()
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
}
