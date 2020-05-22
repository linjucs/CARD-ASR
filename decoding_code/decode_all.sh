#!/bin/bash
 . ./cmd.sh
 . ./path.sh

  cmd=run.pl
  mkdir -p lattice
  dir=lattice
  online2-wav-nnet3-latgen-faster \
  --online=false \
  --print-args=false \
  --do-endpointing=true \
  --frame-subsampling-factor=3 \
  --config=exp/tdnn_7b_chain_online/conf/online.conf \
  --max-active=7000 \
  --beam=15.0 \
  --lattice-beam=6.0 \
  --acoustic-scale=1.0 \
  --word-symbol-table=exp/tdnn_7b_chain_online/graph_pp/words.txt \
  exp/tdnn_7b_chain_online/final.mdl \
  exp/tdnn_7b_chain_online/graph_pp/HCLG.fst \
  'ark:utt2spk' \
  'scp:wav.scp' \
  'ark,t:|gzip -c > lattice/lat.1.gz' || exit 1;

  decode_mbr=false
  stats=true
  beam=6
  word_ins_penalty=0.0,0.5,1.0
  min_lmwt=7
  max_lmwt=17
  iter=final
  symtab=data/lang_chain/words.txt
  mkdir -p $dir/scoring_kaldi
  for f in $dir/lat.1.gz $dir/text; do
  [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
  done
  ref_filtering_cmd="cat"
[ -x local/wer_output_filter ] && ref_filtering_cmd="local/wer_output_filter"
[ -x local/wer_ref_filter ] && ref_filtering_cmd="local/wer_ref_filter"
hyp_filtering_cmd="cat"
[ -x local/wer_output_filter ] && hyp_filtering_cmd="local/wer_output_filter"
[ -x local/wer_hyp_filter ] && hyp_filtering_cmd="local/wer_hyp_filter"
 
 cat $dir/text | $ref_filtering_cmd > $dir/scoring_kaldi/test_filt.txt || exit 1;
#compute-wer --text --mode=present ark:data/train/text ark:hyp_text -
for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    mkdir -p $dir/scoring_kaldi/penalty_$wip/log

      $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/best_path.LMWT.log \
        lattice-scale --inv-acoustic-scale=LMWT "ark,t:gunzip -c $dir/lat.*.gz|" ark:- \| \
        lattice-add-penalty --word-ins-penalty=$wip ark:- ark:- \| \
        lattice-best-path --word-symbol-table=$symtab ark:- ark,t:- \| \
        utils/int2sym.pl -f 2- $symtab \| \
        $hyp_filtering_cmd '>' $dir/scoring_kaldi/penalty_$wip/LMWT.txt || exit 1;
      $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring_kaldi/penalty_$wip/log/score.LMWT.log \
      cat $dir/scoring_kaldi/penalty_$wip/LMWT.txt \| \
      compute-wer --text --mode=present \
      ark:$dir/scoring_kaldi/test_filt.txt ark,p: - ">&"  $dir/wer_LMWT_$wip || exit 1;

  done


for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
    for lmwt in $(seq $min_lmwt $max_lmwt); do
      # adding /dev/null to the command list below forces grep to output the filename
      grep WER $dir/wer_${lmwt}_${wip} /dev/null
    done
  done | utils/best_wer.sh  >& $dir/scoring_kaldi/best_wer || exit 1

  best_wer_file=$(awk '{print $NF}' $dir/scoring_kaldi/best_wer)
  best_wip=$(echo $best_wer_file | awk -F_ '{print $NF}')
  best_lmwt=$(echo $best_wer_file | awk -F_ '{N=NF-1; print $N}')

