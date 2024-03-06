package main

import (
	"fmt"
	"image"
	"image/color"
	"os"

	"github.com/sergeymakinen/go-bmp"
)

func output_bmp_as_raw(filename string) error {
	var img = image.NewRGBA(image.Rect(0, 0, 64, 32))

	for y := 0; y < 32; y++ {
		for x := 0; x < 64; x++ {
			var r, g, b uint8
			_, err := fmt.Scanf("%01x%01x%01x0\n", &r, &g, &b)
			if err != nil {
				return fmt.Errorf("could not parse line: %s", err)
			}
			fmt.Printf("Got %d %d %d\n", r, g, b)
			img.SetRGBA(x, y, color.RGBA{R: r * 16, G: g * 16, B: b * 16, A: 255})
		}
	}

	f, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("could not create file: %s", err)
	}

	bmp.Encode(f, img)

	f.Close()

	return nil
}

func main() {
	args := os.Args[1:]

	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "Filename not specified\n")
		os.Exit(1)
	}
	input_filename := args[0]

	output_bmp_as_raw(input_filename)
}
