//
//  fbaconf.h
//  iFBA
//
//  Created by Yohann Magnien on 29/02/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef iFBA_fbaconf_h
#define iFBA_fbaconf_h

typedef struct {
    //Video
    unsigned char aspect_ratio;
    unsigned char screen_mode;
    unsigned char filtering;
    
    //Audio
    unsigned char sound_on;
    unsigned int sound_freq;
    
    //Controls
    unsigned char vpad_alpha;
    unsigned char btstack_on;
    unsigned char joymaps_wiimotes[4][16];
    unsigned char joymaps_icade[8];    
    
    //Emulation
    unsigned char asm_68k;
    unsigned char asm_z80;
    unsigned char asm_nec;
    unsigned char asm_sh2;
    
    //Extension
    unsigned char extension[64];
} ifba_conf_t;

extern ifba_conf_t ifba_conf;


#endif