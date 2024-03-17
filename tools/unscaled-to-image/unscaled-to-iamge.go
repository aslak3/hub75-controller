package main

import (
	"flag"
	"fmt"
	"image"
	"image/color"
	"os"

	"github.com/sergeymakinen/go-bmp"
)

type unscaledPixel struct {
	r, g, b int
}

func output_bmp_as_raw(filename string) error {
	var img = image.NewRGBA(image.Rect(0, 0, 64, 32))
	var imageArray [64][32]unscaledPixel // copy of data we are fed
	var scale int = 0                    // Maximum value of r g or b of any pixel

	for y := 0; y < 32; y++ {
		for x := 0; x < 64; x++ {
			var r, g, b int
			for {
				_, err := fmt.Scanf("%d,%d,%d\n", &r, &g, &b)
				if err == nil {
					// If it wont pass, just skip this line
					break
				}
			}

			imageArray[x][y].r = r
			imageArray[x][y].g = g
			imageArray[x][y].b = b

			if r > scale {
				scale = r
			}
			if g > scale {
				scale = g
			}
			if b > scale {
				scale = b
			}
		}
	}

	for y := 0; y < 32; y++ {
		for x := 0; x < 64; x++ {
			rgba := color.RGBA{
				// Scale such that the highest brightness, found earlier, is 255
				R: uint8((float32(imageArray[x][y].r) / float32(scale)) * 255.0),
				G: uint8((float32(imageArray[x][y].g) / float32(scale)) * 255.0),
				B: uint8((float32(imageArray[x][y].b) / float32(scale)) * 255.0),
				A: 255}
			fmt.Printf("%+v\n", rgba)
			img.SetRGBA(x, y, rgba)
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
	outputFilenamePtr := flag.String("output-filename", "", "A 64 x 32 bmp file")

	flag.Parse()

	if *outputFilenamePtr == "" {
		fmt.Fprintf(os.Stderr, "Filename not specified\n")
		os.Exit(1)
	}

	output_bmp_as_raw(*outputFilenamePtr)
}
