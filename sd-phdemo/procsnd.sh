
# download source stereo samples in subfolder ./src/
# see below for used freesound.org samples.
# this scripts simply documents the processing procedure - you should uncomment and run sections as you require them

#~ for ix in src/*.{wav,aif}; do echo $(soxi $ix | awk '/Channels|Sample|Precision/ {split($0,a,":"); print a[2]; }') $ix; done

#2 44100 16-bit 16-bit Signed Integer PCM src/110535__soundbyter-com__hihat_www-soundbyter-com-technowithhts.wav
#2 44100 24-bit 24-bit Signed Integer PCM src/130533__stomachache__marimba_g2.wav
#soxi WARN wav: wave header missing FmtExt chunk
#2 44100 24-bit 32-bit Floating Point PCM src/144504__eightball__kick_8b-bd-001.wav
#soxi WARN wav: wave header missing FmtExt chunk
#2 192000 24-bit 32-bit Floating Point PCM src/188715__oceanictrancer__house-kick.wav
#...

# same format and normalization
# use bash substring to remove both src/ and either .wav or .aif:
# don't use -t 16: soxi FAIL formats: WAVE: RIFF header not found
# with this now all have same formats - except for channels (inherited from src)
#~ for ix in src/*.{wav,aif}; do ixb=${ix:4:-4}; echo $ixb; sox --norm $ix -t wav -e signed -b 16 -r 44100 ${ixb}.wav; done
#~ mkdir inp ; mv *.wav inp/

# batch for cutting, etc in Audacity:
#~ for ix in inp/*.wav; do echo $ix; audacity $ix; done

# check if correct tags in name:
#~ for ix in {hat,snare,kick,clap,cymbal,crash,orch,bass,marimba}; do echo -n $(ls inp/*.wav | grep $ix | wc -l)"+"; done
# 5+7+7+5+7+3+3+2+1
# wcalc 5+7+7+5+7+3+3+2+1 = 40
# ls inp/*.wav | wc -l = 40

# rename files to "minimised" names
declare -A nconv
nconv=([hat]=hhat [snare]=snar [kick]=kick [clap]=clap [cymbal]=cymb [crash]=crsh [orch]=orch [bass]=bass [marimba]=mrmb)
for ix in {hat,snare,kick,clap,cymbal,crash,orch,bass,marimba}; do
  echo $ix;
  i=1;
  for ifn in $(ls inp/*.wav | grep $ix); do
    ii=$(printf "%02d" $i) ;
    echo cp $ifn ${nconv[$ix]}_${ii}.wav ;
    #cp $ifn ${nconv[$ix]}_${ii}.wav ;
    ((i++)) ;
  done ;
done

# hat
# cp inp/110535__soundbyter-com__hihat_www-soundbyter-com-technowithhts.wav hhat_01.wav
# cp inp/140521__stomachache__closedhatphrase-005.wav hhat_02.wav
# cp inp/140522__stomachache__closedhatphrase-010.wav hhat_03.wav
# cp inp/29785__stomachache__hattight2.wav hhat_04.wav
# cp inp/44858__stomachache__hihatbrushtight.wav hhat_05.wav
# snare
# cp inp/193023__oceanictrancer__house-snare.wav snar_01.wav
# cp inp/203104__elder-imp__hugesnare5.wav snar_02.wav
# cp inp/207170__veiler__snare-veiler-2013.wav snar_03.wav
# cp inp/79749__sandyrb__dkp-snare-001-woh.wav snar_04.wav
# cp inp/79761__sandyrb__lno-snare-005-woh.wav snar_05.wav
# cp inp/84867__sandyrb__snare_kbsd2-pro37r-velocity6.wav snar_06.wav
# cp inp/92359__sandyrb__snare_pdp-birch-14x5-ambient-velo9.wav snar_07.wav
# kick
# cp inp/110535__soundbyter-com__kick_www-soundbyter-com-technowithhts.wav kick_01.wav
# cp inp/144413__pjcohen__phtlofidrumkitkickbss.wav kick_02.wav
# cp inp/144504__eightball__kick_8b-bd-001.wav kick_03.wav
# cp inp/150474__pjcohen__drummersworldwalnutkickbd18x22.wav kick_04.wav
# cp inp/150498__pjcohen__slingerland1930sgenekruparadiokingbopkitlowtuningkickbd14x28.wav kick_05.wav
# cp inp/188715__oceanictrancer__house-kick.wav kick_06.wav
# cp inp/203102__elder-imp__hugekick2.wav kick_07.wav
# clap
# cp inp/169085__nenadsimic__disco-clap.wav clap_01.wav
# cp inp/201952__michaelkoehler__castanets-clapping.wav clap_02.wav
# cp inp/223834__oceanictrancer__rap-clap-funk-thing.wav clap_03.wav
# cp inp/29800__stomachache__clap_3.wav clap_04.wav
# cp inp/88713__loofa__sweet-claps-014.wav clap_05.wav
# cymbal
# cp inp/145343__westernsynthetics__fuct-cymbal.wav cymb_01.wav
# cp inp/161088__pjcohen__zildjiankcustom20mediumridecymbaledge.wav cymb_02.wav
# cp inp/23542__loofa__brushd-china-cymbal01.wav cymb_03.wav
# cp inp/29791__stomachache__cymbal_ride2.wav cymb_04.wav
# cp inp/33368__jimmy60__cymbal_tambourene.wav cymb_05.wav
# cp inp/34156__clandestine1114__cymbal_silverspoontop2.wav cymb_06.wav
# cp inp/54039__arnaud-coutancier__little-cymbals-petites-crotales.wav cymb_07.wav
# crash
# cp inp/152681__stomachache__mscrash1.wav crsh_01.wav
# cp inp/153400__stomachache__crash1ms.wav crsh_02.wav
# cp inp/153404__stomachache__crash-a-ms1.wav crsh_03.wav
# orch
# cp inp/153405__copyc4t__dundundunnnextreme_orch.wav orch_01.wav
# cp inp/239615__eguaus__orchestra-tuning.wav orch_02.wav
# cp inp/90741__bigdumbweirdo__orch-hit.wav orch_03.wav
# bass
# cp inp/213900__garzul__badass-minimoog-bass-c4.wav bass_01.wav
# cp inp/254708__jagadamba__basspad07-stereo.wav bass_02.wav
# marimba
# cp inp/130533__stomachache__marimba_g2.wav mrmb_01.wav

#~ S: Badass Minimoog bass C4 by Garzul -- http://www.freesound.org/people/Garzul/sounds/213900/ -- License: Creative Commons 0
#S: BassPad07_Stereo by Jagadamba -- http://www.freesound.org/people/Jagadamba/sounds/254708/ -- License: Attribution Noncommercial
#S: DunDunDunnnExtreme.wav by copyc4t -- http://www.freesound.org/people/copyc4t/sounds/153405/ -- License: Attribution
#S: Orch Hit.wav by BigDumbWeirdo -- http://www.freesound.org/people/BigDumbWeirdo/sounds/90741/ -- License: Creative Commons 0
#S: orchestra tuning by eguaus -- http://www.freesound.org/people/eguaus/sounds/239615/ -- License: Creative Commons 0
#S: rap clap (funk thing) by oceanictrancer -- http://www.freesound.org/people/oceanictrancer/sounds/223834/ -- License: Creative Commons 0
#S: 3.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/29800/ -- License: Creative Commons 0
#S: Castanets clapping by michaelkoehler -- http://www.freesound.org/people/michaelkoehler/sounds/201952/ -- License: Attribution
#S: Sweet CLAPS 014.aif by loofa -- http://www.freesound.org/people/loofa/sounds/88713/ -- License: Attribution Noncommercial
#S: Disco Clap by NenadSimic -- http://www.freesound.org/people/NenadSimic/sounds/169085/ -- License: Creative Commons 0
#S: MScrash1.WAV by stomachache -- http://www.freesound.org/people/stomachache/sounds/152681/ -- License: Creative Commons 0
#S: Crash1MS.WAV by stomachache -- http://www.freesound.org/people/stomachache/sounds/153400/ -- License: Creative Commons 0
#S: CRASH_A_MS1.WAV by stomachache -- http://www.freesound.org/people/stomachache/sounds/153404/ -- License: Creative Commons 0
#S: g2.WAV by stomachache -- http://www.freesound.org/people/stomachache/sounds/130533/ -- License: Creative Commons 0
#S: fuct_cymbal.wav by westernsynthetics -- http://www.freesound.org/people/westernsynthetics/sounds/145343/ -- License: Attribution
#S: SilverSpoonTop2.wav by clandestine1114 -- http://www.freesound.org/people/clandestine1114/sounds/34156/ -- License: Sampling+
#S: tambourene.wav by Jimmy60 -- http://www.freesound.org/people/Jimmy60/sounds/33368/ -- License: Sampling+
#S: little cymbals petites crotales.wav by arnaud coutancier -- http://www.freesound.org/people/arnaud%20coutancier/sounds/54039/ -- License: Attribution Noncommercial
#S: ride2.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/29791/ -- License: Creative Commons 0
#S: ZildjianKCustom20MediumRideCymbalEdge.wav by pjcohen -- http://www.freesound.org/people/pjcohen/sounds/161088/ -- License: Attribution
#S: BRUSHD CHINA CYMBAL01.aif by loofa -- http://www.freesound.org/people/loofa/sounds/23542/ -- License: Attribution Noncommercial
#S: OH Spaced-stereo.flac by iainf -- http://www.freesound.org/people/iainf/sounds/38414/ -- License: Sampling+
#S: Rhythmmakerloop 125 bpm-44.wav by Jovica -- http://www.freesound.org/people/Jovica/sounds/5190/ -- License: Attribution
#S: hattight2.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/29785/ -- License: Creative Commons 0
#S: www.soundbyter.com-technowithhats.wav by soundbyter.com -- http://www.freesound.org/people/soundbyter.com/sounds/110535/ -- License: Sampling+
#S: hihatbrushtight.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/44858/ -- License: Creative Commons 0
#S: closedhatPhrase 010.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/140522/ -- License: Creative Commons 0
#S: closedhatPhrase 005.wav by stomachache -- http://www.freesound.org/people/stomachache/sounds/140521/ -- License: Creative Commons 0
#S: HUGESNARE5.wav by Elder_Imp -- http://www.freesound.org/people/Elder_Imp/sounds/203104/ -- License: Attribution Noncommercial
#S: PDP BIRCH 14x5 AMBIENT VELO9.wav by sandyrb -- http://www.freesound.org/people/sandyrb/sounds/92359/ -- License: Attribution
#S: KBSD2 PRO37R VELOCITY6.wav by sandyrb -- http://www.freesound.org/people/sandyrb/sounds/84867/ -- License: Attribution
#S: snare_veiler_2013.wav by Veiler -- http://www.freesound.org/people/Veiler/sounds/207170/ -- License: Attribution Noncommercial
#S: DKP SNARE 001 - WOH.wav by sandyrb -- http://www.freesound.org/people/sandyrb/sounds/79749/ -- License: Attribution
#S: LNO SNARE 005 - WOH.wav by sandyrb -- http://www.freesound.org/people/sandyrb/sounds/79761/ -- License: Attribution
#S: house snare by oceanictrancer -- http://www.freesound.org/people/oceanictrancer/sounds/193023/ -- License: Creative Commons 0
#S: 8B_BD-001.wav by eightball -- http://www.freesound.org/people/eightball/sounds/144504/ -- License: Creative Commons 0
#S: Slingerland1930sGeneKrupaRadioKingBopKitLowTuningKickBD14x28.wav by pjcohen -- http://www.freesound.org/people/pjcohen/sounds/150498/ -- License: Attribution
#S: PhatLoFiDrumKitKickBass.wav by pjcohen -- http://www.freesound.org/people/pjcohen/sounds/144413/ -- License: Attribution
#S: DrummersWorldWalnutKickBD18x22.wav by pjcohen -- http://www.freesound.org/people/pjcohen/sounds/150474/ -- License: Attribution
#S: HUGEKICK2.wav by Elder_Imp -- http://www.freesound.org/people/Elder_Imp/sounds/203102/ -- License: Attribution Noncommercial
#S: house kick by oceanictrancer -- http://www.freesound.org/people/oceanictrancer/sounds/188715/ -- License: Creative Commons 0
