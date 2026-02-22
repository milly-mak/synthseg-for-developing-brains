# Infant pipeline development code

This repository tests two hypotheses:

1. That SyntSeg is sensitive brain size, and therefore struggles to process infant scans.
2. That SynthSeg performs better on cropped brain images. 

### Register BOPS 'ground truth' segmentations into BCP-space
`Register-BCP-BOPS/register-BCP-to-BOPS.sh` - Takes the BOPS manually curated ground truth segmentations, and registers them into BCP space:

