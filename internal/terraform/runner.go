package terraform

import (
	"os"
	"os/exec"
)

type Runner struct {
	Dir string
}

func NewRunner(dir string) *Runner {
	return &Runner{Dir: dir}
}

func (r *Runner) Init() error {
	return r.run("init", "-reconfigure")
}

func (r *Runner) Plan() error {
	return r.run("plan")
}

func (r *Runner) run(args ...string) error {

	cmd := exec.Command("terraform", args...)
	cmd.Dir = r.Dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	return cmd.Run()
}
