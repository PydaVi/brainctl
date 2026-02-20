package cli

import (
	"encoding/json"
	"fmt"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/PydaVi/brainctl/internal/cost"
)

func newCostCommand(opts *RuntimeOptions) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cost",
		Short: "Estimate infra base cost using Infracost (service/hour and service/month)",
		RunE: withRuntime(*opts, false, func(cmd *cobra.Command, args []string, ctx *runtimeContext) error {
			if _, err := exec.LookPath("infracost"); err != nil {
				return fmt.Errorf("infracost não encontrado no PATH. Instale em https://www.infracost.io/docs/ ou via curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh")
			}

			if err := ctx.Runner.Init(); err != nil {
				return err
			}

			report, err := cost.EstimateInfraBase(ctx.WSDir)
			if err != nil {
				return err
			}

			asJSON, _ := cmd.Flags().GetBool("json")
			if asJSON {
				b, err := json.MarshalIndent(report, "", "  ")
				if err != nil {
					return err
				}
				fmt.Println(string(b))
				return nil
			}

			printCostReport(report)
			return nil
		}),
	}

	applyCommonFlags(cmd, opts)
	cmd.Flags().Bool("json", false, "Print report in JSON format")
	return cmd
}

func printCostReport(r *cost.Report) {
	fmt.Println("== brainctl cost (infra base) ==")
	fmt.Println("Service              Hourly (USD)    Monthly (USD)")
	fmt.Println("----------------------------------------------------")
	for _, s := range r.Services {
		fmt.Printf("%-20s %12.4f %14.2f\n", s.Service, s.Hourly, s.Monthly)
	}
	fmt.Println("----------------------------------------------------")
	fmt.Printf("%-20s %12.4f %14.2f\n", "TOTAL", r.TotalHourly, r.TotalMonthly)
}
