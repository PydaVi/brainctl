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

			wsDir, err := workspace.Prepare(cfg) // cria .brainctl/apps/<name>/<env>/
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
	root.AddCommand(planCmd)

	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
