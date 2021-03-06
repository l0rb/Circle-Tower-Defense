// ========== SETTINGS ========== //

class Settings {

   static inline private var size= 2;

   static inline public var fontsize_small= 4*size;
   static inline public var fontsize_std= 6*size;
   static inline public var fontsize_big= 11*size;

   static inline public var font= "DejaVu Sans Mono";

   static inline public var tilesize= 24;
   static inline public var creep_speedfactor= 2; // (tilesize/creep_speedfactor)%2==0 advisabe
   static inline public var bullet_speedfactor= 4;
   static inline public var wavesize= 10; // number of creeps per wave
   static inline public var wavetime= 12; // time in seconds between waves
   static inline public var spawntime= 666; // time in milliseconds between creeps
   static inline public var death= 10; // game over if this many creeps on screen
   
   static inline public var start_gold= 40;
}
class Colors {
   static inline public var black= 0x000000;
   static inline public var white= 0xffffff;
   static inline public var valid= 0x00ff00; // green, for allowed actions (e.g "can build here")
   static inline public var invalid= 0xff0000; // red, to mark stuff that doesn't work (e.g. "not enough gold")
   
   static inline public var button= 0xcc80e6;
   static inline public var button_hover= 0xad33a6;
   static inline public var button_border= black;
}

// ======== END SETTINGS ======== //


