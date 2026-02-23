package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/creack/pty"
)

type EditorDriver interface {
	Start(filePath string) (time.Duration, error)
	SendKeys(keys string, delay time.Duration) error
	Quit(force bool) (time.Duration, error)
	GetName() string
}

type BaseDriver struct {
	Name      string
	CmdPath   string
	Args      []string
	PTY       *os.File
	Process   *os.Process
	StartTime time.Time
}

func (d *BaseDriver) GetName() string {
	return d.Name
}

func (d *BaseDriver) Start(filePath string) (time.Duration, error) {
	args := append([]string{}, d.Args...)
	if filePath != "" {
		args = append(args, filePath)
	}

	cmd := exec.Command(d.CmdPath, args...)
	start := time.Now()

	f, err := pty.Start(cmd)
	if err != nil {
		return 0, err
	}

	d.PTY = f
	d.Process = cmd.Process
	d.StartTime = start

	ready := make(chan bool)
	go func() {
		buf := make([]byte, 8192)
		firstRead := true
		for {
			_, err := d.PTY.Read(buf)
			if firstRead {
				ready <- true
				firstRead = false
			}
			if err != nil {
				return
			}
		}
	}()

	select {
	case <-ready:
		return time.Since(start), nil
	case <-time.After(5 * time.Second):
		return 0, fmt.Errorf("%s timed out waiting for ready", d.Name)
	}
}

func (d *BaseDriver) SendKeys(keys string, delay time.Duration) error {
	if d.PTY == nil {
		return fmt.Errorf("editor not running")
	}

	converted := d.convertKeys(keys)
	for _, b := range converted {
		if _, err := d.PTY.Write([]byte{b}); err != nil {
			return err
		}
		if delay > 0 {
			time.Sleep(delay)
		}
	}
	return nil
}

func (d *BaseDriver) convertKeys(keys string) []byte {
	var out []byte
	for i := 0; i < len(keys); i++ {
		if keys[i] == '<' {
			end := strings.IndexByte(keys[i:], '>')
			if end != -1 {
				special := keys[i+1 : i+end]
				out = append(out, d.specialKeyBytes(special)...)
				i += end
				continue
			}
		}
		out = append(out, keys[i])
	}
	return out
}

func (d *BaseDriver) specialKeyBytes(key string) []byte {
	switch key {
	case "CR":
		return []byte("\r")
	case "NL":
		return []byte("\n")
	case "ESC":
		return []byte("\x1b")
	case "BS":
		return []byte("\x08")
	case "Tab":
		return []byte("\t")
	case "Space":
		return []byte(" ")
	case "Up":
		return []byte("\x1b[A")
	case "Down":
		return []byte("\x1b[B")
	case "Right":
		return []byte("\x1b[C")
	case "Left":
		return []byte("\x1b[D")
	}
	if strings.HasPrefix(key, "C-") && len(key) == 3 {
		return []byte{key[2] - 96}
	}
	return nil
}

func (d *BaseDriver) Quit(force bool) (time.Duration, error) {
	start := time.Now()
	cmd := "<ESC>:q<CR>"
	if force {
		cmd = "<ESC>:q!<CR>"
	}
	_ = d.SendKeys(cmd, 10*time.Millisecond)

	done := make(chan error)
	go func() {
		if d.Process != nil {
			_, err := d.Process.Wait()
			done <- err
		} else {
			done <- nil
		}
	}()

	select {
	case err := <-done:
		d.cleanup()
		return time.Since(start), err
	case <-time.After(2 * time.Second):
		if d.Process != nil {
			_ = d.Process.Kill()
		}
		d.cleanup()
		return time.Since(start), fmt.Errorf("timeout waiting for %s to quit", d.Name)
	}
}

func (d *BaseDriver) cleanup() {
	if d.PTY != nil {
		d.PTY.Close()
		d.PTY = nil
	}
	d.Process = nil
}

type VidereDriver struct {
	BaseDriver
}

func NewVidereDriver() *VidereDriver {
	path, _ := os.Getwd()
	// Adjusting path to find built binary in project root
	// Since tests run in cmd/videre, project root is ../..
	viderePath := fmt.Sprintf("%s/../../videre", path)
	if _, err := os.Stat(viderePath); err != nil {
		viderePath = "videre"
	}
	return &VidereDriver{
		BaseDriver: BaseDriver{
			Name:    "videre",
			CmdPath: viderePath,
		},
	}
}

type NvimDriver struct {
	BaseDriver
}

func NewNvimDriver() *NvimDriver {
	return &NvimDriver{
		BaseDriver: BaseDriver{
			Name:    "nvim",
			CmdPath: "nvim",
			Args:    []string{"--noplugin", "-u", "NONE"},
		},
	}
}
