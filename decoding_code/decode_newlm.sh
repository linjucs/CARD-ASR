#!/bin/bash
  online2-wav-nnet3-latgen-faster \
  --online=false \
  --print-args=false \
  --do-endpointing=true \
  --frame-subsampling-factor=3 \
  --config=new/conf/online.conf \
  --max-active=7000 \
  --beam=15.0 \
  --lattice-beam=6.0 \
  --acoustic-scale=1.0 \
  --word-symbol-table=new/graph/words.txt \
  exp/tdnn_7b_chain_online/final.mdl \
  new/graph/HCLG.fst \
  'ark:utt2spk' \
  'scp:wav.scp' \
  'ark:/dev/null'
