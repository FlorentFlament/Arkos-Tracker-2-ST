;
; Very tiny shell for calling the Arkos 2 ST player
; Cobbled by GGN in 20 April 2018
; Uses rmac for assembling (probably not a big problem converting to devpac/vasm format)
;

;--------------------------------------------------------------
;-- Pre-processing of events
;
; # Export "you_never_can_tell.events.s"
; # Copy that file to "you_never_can_tell.events.words.s"
; # The very last dc.w is the loopback label. Change the dc.w to dc.l
; # Change all dc.b's to dc.w
;
;-- Pre-processing of events
;--------------------------------------------------------------
;-- Using events to turn on/off SID on channels
;
; # In this file, set:
;     SID_VOICES=1
;     USE_EVENTS=1
;     USE_SID_EVENTS=1
; # In Arkos Tracker 2, all events starting with F (F0, F1, F2 etc up to FF)
;   are now SID events. The lowest three bits control which channels are SID-
;   enabled. Timers used are ABD (for channels ABC, respectively).
;   The bit pattern is 1111 xABC, which means:
;     F0 - No channels use SID - no timers
;     F1 - Only channel C uses SID - timer D only
;     F2 - Only channel B uses SID - timer B only
;     F3 - Channels B and C use SID - timer B and D
;     F4 - Only channel A uses SID - timer A only
;     F5 - Channels A and C use SID - timer A and D
;     F6 - Channels A and B use SID - timer A and B
;     F7 - All channels use SID - timers A, B and D
;
;-- Using events to turn on/off SID on channels
;--------------------------------------------------------------


debug=0                             ;1=skips installing a timer for replay and instead calls the player in succession
                                    ;good for debugging the player but plays the tune in turbo mode :)
show_cpu=1                          ;if 1, display a bar showing CPU usage
use_vbl=0                           ;if enabled, vbl is used instead of timer c
disable_timers=0                    ;if 1, stops all MFP timers, for better CPU usage display
UNROLLED_CODE=0                     ;if 1, enable unrolled slightly faster YM register reading code
SID_VOICES=1                        ;if 1, enable SID voices (takes more CPU time!)
PC_REL_CODE=0                       ;if 1, make code PC relative (helps if you move the routine around, like for example SNDH)
AVOID_SMC=0                         ;if 1, assemble the player without SMC stuff, so it should be fine for CPUs with cache
tune_freq = 200                     ;tune frequency in ticks per second
USE_EVENTS=1                        ;if 1, include events, and parse them
USE_SID_EVENTS=1                    ;if 1, use events to control SID.
                                    ;  $Fn=sid setting, where n bits are xABC for which voice to use SID

  ; error checking illegal combination of USE_EVENTS and USE_SID_EVENTS
  .if USE_SID_EVENTS=1
    .if USE_EVENTS=0
      error
      dc.b "You can't use sid events if USE_EVENTS is 0"
    .endif ; .if USE_EVENTS=0
  .endif ; .if USE_SID_EVENTS=1

EVENT_CHANNEL_A_MASK equ 4
EVENT_CHANNEL_B_MASK equ 2
EVENT_CHANNEL_C_MASK equ 1

    pea start(pc)                   ;go to start with supervisor mode on
    move.w #$26,-(sp)
    trap #14

    clr.w -(sp)                     ;terminate
    trap #1

start:

    .if SID_VOICES
    clr.b chan_a_sid_on
    clr.b chan_b_sid_on
    clr.b chan_c_sid_on
    .endif ; .if SID_VOICES
    
    .if USE_EVENTS
    ; reset event pos to start of event list
    lea tune_events,a0
    move.l a0,events_pos
    move.w (a0),event_counter
    .endif ; .if USE_EVENTS
    
    
    move.b $484.w,-(sp)             ;save old keyclick state
    clr.b $484.w                    ;keyclick off, key repeat off

    lea tune,a0
    bsr PLY_AKYst_Init              ;init player and tune
    .if SID_VOICES
    bsr sid_ini                     ;init SID voices player
    .endif ; .if SID_VOICES

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1                   ;install our very own vbl

    .if disable_timers=1
    lea save_mfp(pc),a0
    move.b $fffffa07.w,(a0)+        ;save MFP timer status
    move.b $fffffa0b.w,(a0)+
    move.b $fffffa0f.w,(a0)+
    move.b $fffffa13.w,(a0)+
    move.b $fffffa09.w,(a0)+
    move.b $fffffa0d.w,(a0)+
    move.b $fffffa11.w,(a0)+
    move.b $fffffa15.w,(a0)+
    clr.b $fffffa07.w               ;disable all timers
    clr.b $fffffa0b.w
    clr.b $fffffa0f.w
    clr.b $fffffa13.w
    clr.b $fffffa09.w
    clr.b $fffffa0d.w
    clr.b $fffffa11.w
    clr.b $fffffa15.w
    .endif ; .if disable_timers=1
    
    move.l  $70.w,old_vbl           ;so how do you turn the player on?
    move.l  #vbl,$70.w              ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    .else ; .if use_vbl=1           ;install our very own timer C
    move.l  $114.w,old_timer_c      ;so how do you turn the player on?
    move.l  #timer_c,$114.w         ;(makes gesture of turning an engine key on) *trrrrrrrrrrrrrr*
    .endif ; .if use_vbl=1
    move (sp)+,sr                   ;enable interrupts - tune will start playing
    .endif ; .if !debug
    
.waitspace:

    .if debug
    lea tune,a0                     ;tell the player where to find the tune start
    bsr PLY_AKYst_Play              ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    .endif ; .if SID_VOICES
    .endif ; .if debug

    cmp.b #57,$fffffc02.w           ;wait for space keypress
    bne.s .waitspace

    .if !debug
    move sr,-(sp)
    move #$2700,sr
    .if use_vbl=1
    move.l  old_vbl,$70.w           ;restore vbl

    .if SID_VOICES
    bsr sid_exit
    .endif
    .if disable_timers=1
    lea save_mfp(pc),a0
    move.b (a0)+,$fffffa07.w        ;restore MFP timer status
    move.b (a0)+,$fffffa0b.w
    move.b (a0)+,$fffffa0f.w
    move.b (a0)+,$fffffa13.w
    move.b (a0)+,$fffffa09.w
    move.b (a0)+,$fffffa0d.w
    move.b (a0)+,$fffffa11.w
    move.b (a0)+,$fffffa15.w
    move.b #192,$fffffa23.w         ;kick timer C back into activity
    .endif

    .else
    .if SID_VOICES
    bsr sid_exit
    .endif
    move.l  old_timer_c,$114.w      ;restore timer c
    move.b  #$C0,$FFFFFA23.w        ;and how would you stop the ym?
    .endif
i set 0
    rept 14
    move.l  #i,$FFFF8800.w          ;(makes gesture of turning an engine key off) just turn it off!
i set i+$01010000
    endr
    move (sp)+,sr                   ;enable interrupts - tune will stop playing
    .endif
    
    move.b (sp)+,$484.w             ;restore keyclick state

    rts                             ;bye!

    .if !debug
    .if use_vbl=1
vbl:
    movem.l d0-a6,-(sp)

    .if 0
    move.w #2047,d0                 ;small software pause so we can see the cpu time
.wait: dbra d0,.wait
    .endif ; .if 0

    lea tune,a0                     ;tell the player where to find the tune start
    .if show_cpu
    not.w $ffff8240.w
    .endif ; .if show_cpu

      ;########################################################
      ;## Parse tune events

      .if USE_EVENTS
      movem.l d0/a0,-(sp)
      clr.b event_flag
.event_do_count:
      move.w event_counter,d0
      subq #1,d0
      bne.s .nohit
.event_read_val:
      ; time to read value
      move.l events_pos,a0
      addq #2,a0
      move.w (a0)+,d0
      move.b d0,event_byte
      move.b #1,event_flag ; there's a new event value to fetch
      move.w (a0),d0
      bne.s .noloopback
      ; loopback
      addq #2,a0
      move.l (a0),a0
      move.l a0,events_pos
      move.w (a0),event_counter
      bra.s .event_do_count
.noloopback:
      move.l a0,events_pos
.nohit:
      move.w d0,event_counter
      ;done
      movem.l (sp)+,d0/a0
      .endif ; .if USE_EVENTS

      .if USE_SID_EVENTS
      tst.b event_flag
      beq.s .no_event
      movem.l d0-d1,-(sp)
      move.b event_byte,d0
      move.b d0,d1
      and.b #$f0,d1
      cmp.b #$f0,d1
      bne.s .no_sid_event
      move.b d0,d1
      and.b #EVENT_CHANNEL_A_MASK,d1
      move.b d1,chan_a_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_B_MASK,d1
      move.b d1,chan_b_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_C_MASK,d1
      move.b d1,chan_c_sid_on
.no_sid_event:
      movem.l (sp)+,d0-d1
.no_event:
      .endif ; .if USE_SID_EVENTS

      ;## Parse tune events
      ;########################################################

    bsr.s PLY_AKYst_Play            ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    .endif ; .if SID_VOICES
    .if show_cpu
    not.w $ffff8240.w
    .endif ; .if show_cpu
    movem.l (sp)+,d0-a6    
    .if disable_timers!=1
old_vbl=*+2
    jmp 'GGN!'
    .else ; .if disable_timers!=1
    rte
old_vbl: ds.l 1
save_mfp:   ds.l 16
    .endif ; .if disable_timers!=1
    .else ; .if use_vbl=1
timer_c:
	move.w #$2500,sr                ;mask out all interrupts apart from MFP
    sub.w #tune_freq,timer_c_ctr    ;is it giiiirooo day tom?
    ;bgt.s timer_c_jump              ;sadly derek, no it's not giro day
    bgt timer_c_jump                ;sadly derek, no it's not giro day
    add.w #200,timer_c_ctr          ;it is giro day, let's reset the 200Hz counter
    movem.l d0-a6,-(sp)             ;save all registers, just to be on the safe side
    .if show_cpu
    not.w $ffff8240.w
    .endif ; .if show_cpu
    lea tune,a0                     ;tell the player where to find the tune start

      ;########################################################
      ;## Parse tune events

      .if USE_EVENTS
      movem.l d0/a0,-(sp)
      clr.b event_flag
.event_do_count:
      move.w event_counter,d0
      subq #1,d0
      bne.s .nohit
.event_read_val:
      ; time to read value
      move.l events_pos,a0
      addq #2,a0
      move.w (a0)+,d0
      move.b d0,event_byte
      move.b #1,event_flag ; there's a new event value to fetch
      move.w (a0),d0
      bne.s .noloopback
      ; loopback
      addq #2,a0
      move.l (a0),a0
      move.l a0,events_pos
      move.w (a0),event_counter
      bra.s .event_do_count
.noloopback:
      move.l a0,events_pos
.nohit:
      move.w d0,event_counter
      ;done
      movem.l (sp)+,d0/a0
      .endif ; .if USE_EVENTS

      .if USE_SID_EVENTS
      tst.b event_flag
      beq.s .no_event
      movem.l d0-d1,-(sp)
      move.b event_byte,d0
      move.b d0,d1
      and.b #$f0,d1
      cmp.b #$f0,d1
      bne.s .no_sid_event
      move.b d0,d1
      and.b #EVENT_CHANNEL_A_MASK,d1
      move.b d1,chan_a_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_B_MASK,d1
      move.b d1,chan_b_sid_on
      move.b d0,d1
      and.b #EVENT_CHANNEL_C_MASK,d1
      move.b d1,chan_c_sid_on
.no_sid_event:
      movem.l (sp)+,d0-d1
.no_event:
      .endif ; .if USE_SID_EVENTS

      ;## Parse tune events
      ;########################################################

    bsr.s PLY_AKYst_Play            ;play that funky music
    .if SID_VOICES
    lea values_store(pc),a0
    bsr sid_play
    .endif ; .if SID_VOICES
    .if show_cpu
    not.w $ffff8240.w
    .endif ; .if show_cpu
    movem.l (sp)+,d0-a6             ;restore registers

old_timer_c=*+2
timer_c_jump:
    jmp 'AKY!'                      ;jump to the old timer C vector
timer_c_ctr: dc.w 200
    .endif ; .if use_vbl=1
    .endif ; .if !debug

    .include "PlayerAky.s"

    .if SID_VOICES
    .include "sid.s"
    .endif ; .if SID_VOICES

    .data

  .if USE_EVENTS
events_pos: ds.l 1
event_counter: ds.w 1
event_byte: dc.b 0
event_flag: dc.b 0
  .even
tune_events:
;    .include "tunes/SID_Test_001.events.words.s"
    .include "tunes/knightmare.events.words.s"
;    .include "tunes/you_never_can_tell.events.words.s"

;    .include "tunes/ten_little_endians.events.words.s"
;    .include "tunes/just_add_cream.events.words.s"
;    .include "tunes/interleave_this.events.words.s"
  .even
  .endif ; .if USE_EVENTS

tune:
;   .include "tunes/UltraSyd - Fractal.s"
;    .include "tunes/UltraSyd - YM Type.s"
;    .include "tunes/Targhan - Midline Process - Carpet.s"
;    .include "tunes/Targhan - Midline Process - Molusk.s"
;    .include "tunes/Targhan - DemoIzArt - End Part.s"
;    .include "tunes/Pachelbel's Canon in D major 003.s"
;    .include "tunes/Interleave THIS! 015.s"
;    .include "tunes/Knightmare 200Hz 017.s"
;    .include "tunes/Ten Little Endians_015.s"
;    .include "tunes/Just add cream 020.s"

;    .include "tunes/SID_Test_001.aky.s"
    .include "tunes/knightmare.aky.s"
;    .include "tunes/you_never_can_tell.aky.s"

;    .include "tunes/ten_little_endians.aky.s"
;    .include "tunes/just_add_cream.aky.s"
;    .include "tunes/interleave_this.aky.s"

    .long                            ;pad to 4 bytes
tune_end:

    .bss

