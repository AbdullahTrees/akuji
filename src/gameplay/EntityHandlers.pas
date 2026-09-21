{ Per-type entity behavior dispatched by Entity_UpdateAll. }

unit EntityHandlers;

{$MODE DELPHI}{$H+}

interface

uses
  SysUtils, Entities, GameState, SoundTable, PlayerState, Player, Directions;

const
  { Contiguous sprite-table data. Some unchecked lookups can cross into an
    adjacent table, so the complete region remains one array. Reads beyond
    this region are clamped for safety. }
  SPRITE_DATA_BASE = $0046BC2C;
  SPRITE_DATA: array[0..245] of Integer = (
      28,   29,   30,   31,   32,   33,   34,   35,   36,   37,
      38,   39,   20,   21,   22,   23,   24,   25,   26,   27,
     200,  201,  202,  203,  204,  205,  206,  207,  208,  209,
     210,  211,   40,   41,   42,   43,  233,  234,  235,  236,
      50,   51,   52,   53,  212,  213,  214,  215,  216,  217,
     218,   64,   65,   66,   65,   67,   68,   69,   70,  219,
     220,  221,  240,  241,  240,  241,  242,  243,  242,  243,
     244,  245,  244,  245,  231,  232,  256,  257,  256,  257,
     258,  259,  258,  259,  260,  261,  260,  261,  283,  284,
     285,  286,  287,   71,   72,   73,   72,  118,  119,  120,
     119,   74,   75,   76,   77,   78,   79,   80,   81,  480,
     482,  483,  484,  485,  486,  487,  488,  480,  481,   82,
     104,  105,   83,   99,  102,  103,   84,   85,  279,  280,
     281,  282,   93,   94,   95,   96,   97,   98,  100,  101,
     222,  223,  224,  225,  226,  222,   54,   61,   62,   59,
      60,   63,   87,   86,   88,   86,   89,   90,   91,   92,
       8,   10,   12,   60,   30,   10,    8,    6,    4,    0,
      10,   20,  500,  501,  502,  501,  503,  512,  513,  514,
     515,  516,  504,  505,  506,  507,  508,  509,  510,  511,
     110,  111,  112,  113,  106,  107,  108,  109,  120,   60,
      30,  227,  228,  229,  230,  246,  247,  248,  249,  250,
     251,    2,    2,    3,    4,    2,    1,  123,  124,  125,
     124,  192,  193,  194,  193,  240,  180,  180,  126,  127,
     128,  127,  129,  130,   30,   20,   10,  120,   60,   30,
      30,   20,   10,    1,    3,    5);

  { Offsets into the contiguous sprite region. Each row holds four integers. }
  SPRITE_ROW = 4;
  T2_AT    = ($0046BC2C - SPRITE_DATA_BASE) div 4;
  T7_AT    = ($0046BCAC - SPRITE_DATA_BASE) div 4;
  MANA_AT  = ($0046BDA0 - SPRITE_DATA_BASE) div 4;
  T38_AT   = ($0046BF24 - SPRITE_DATA_BASE) div 4;

  MANA_VARIANTS = 2;
  MANA_FRAMES   = 4;
  MANA_SPRITE_TABLE_ADDR = $0046BDA0;
  MANA_SPRITE_TABLE_PTR  = $0046CBA0;
  MANA_SPRITES: array[0..MANA_VARIANTS - 1, 0..MANA_FRAMES - 1] of Integer = (
    ( 71,  72,  73,  72),
    (118, 119, 120, 119));

  { Type 24 uses EF_FACING as the phase of its vertical bob. Each variant has
    one sprite except variant 8, which alternates between two frames and plays
    the heartbeat sound every 61 frames. }
  ITEM24_VARIANTS   = 16;
  ITEM24_TABLE_ADDR = $0046BDC0;
  ITEM24_TABLE_PTR  = $0046D0E4;
  ITEM24_SPRITES: array[0..ITEM24_VARIANTS - 1] of Integer = (
     74,  75,  76,  77,  78,  79,  80,  81,
    480, 482, 483, 484, 485, 486, 487, 488);

  ITEM24_BEAT_VARIANT = 8;
  ITEM24_BEAT_ADDR    = $0046BE00;
  ITEM24_BEAT_PTR     = $0046D32C;
  ITEM24_BEAT_FRAMES  = 2;
  ITEM24_BEAT_SPRITES: array[0..ITEM24_BEAT_FRAMES - 1] of Integer = (480, 481);
  ITEM24_BEAT_TICKS   = $3C;   { 60; the sound fires when the count EXCEEDS it }

  { Type 25 is static scenery with three single-sprite variants. }
  ITEM25_VARIANTS   = 3;
  ITEM25_TABLE_ADDR = $0046BE08;
  ITEM25_TABLE_PTR  = $0046CF00;
  ITEM25_SPRITES: array[0..ITEM25_VARIANTS - 1] of Integer = (82, 104, 105);

  { Type 27 is animated scenery whose attached event implements a save point. }
  SAVE_POINT_FRAMES = 2;
  SAVE_POINT_ADDR   = $0046BE24;
  SAVE_POINT_PTR    = $0046D18C;
  SAVE_POINT_SPRITES: array[0..SAVE_POINT_FRAMES - 1] of Integer = (84, 85);
  SAVE_POINT_TICKS  = 8;   { advance when the count EXCEEDS it, so every 9 }

  { The one-shot drop applied on the first update, in 1/32 pixel - five pixels.
    Events place things on a tile boundary and this settles them onto it. }
  MANA_SETTLE_DROP = $A0;
  MANA_FRAME_TICKS = 4;   { advance when the timer EXCEEDS this, so every 5 }

  { Slots this handler uses. int 5 is the drawn sprite id, the same slot
    Player_Update writes - it is entity-wide, not the player's. int 6 is the
    variant. Both sit outside the two 10-int blocks. }
  { EF_ANIM_ID and EF_VARIANT moved to Entities.pas - they are core entity
    fields, not handler-local ones, and the event spawn walk needs them too. }

  { Touch kinds 2 and 5 follow the same pickup sequence:
    change the player's state, set the progress flag named by the event's
    ParamB, put a type 26 effect where the entity was, and destroy themselves.
    The effect's VARIANT is how one entity type shows three different pickups.

    The Mana Stone's variant is also its value: 0 adds one, 1 adds ten. }
  PICKUP_EFFECT_TYPE = $1A;   { 26 }
  MANA_SMALL = 1;
  MANA_LARGE = 10;
  PICKUP_FX_NORMAL  = 0;
  PICKUP_FX_LEVELUP = 1;
  PICKUP_FX_HEAL    = 3;

  { Seven touch kinds run after one overlap test and
    three guards first: the player must not be invulnerable UNLESS the kind is
    3 - which is the only kind that reaches through invulnerability - the
    entity's own EF_TIMER must be 0, and a kind of 0 is not a touch at all.

    Opcode 1, "walk up and press", needs the player STANDING, Up held, and
    Inp.AxisYNegative still clear, which is the edge; the latch is set the
    frame after, so holding Up does not retrigger.

    The dispatcher has no meaningful result. }
  TOUCH_KIND_HURT       = 1;
  TOUCH_KIND_MANA       = 2;
  TOUCH_KIND_THRU_INVULN = 3;
  TOUCH_KIND_LIFE       = 4;
  TOUCH_KIND_HEAL       = 5;
  TOUCH_KIND_STOMP      = 6;
  TOUCH_KIND_HURT_HARD  = 7;

  { Player damage grants ninety invulnerability frames, enters knockback state
    8, and throws the player up and
    away from whichever way it is facing.

    The lost-life particles spawn at the HUD LIFE ICON, not at the player:
    x = Lives * 16 + 20 pixels, y = 16. They are type 13, which the type table
    marks screen-space, so they do not scroll - the icon is visibly knocked off
    the display. Three per life lost, and the loop stops early if lives run
    out before the damage does. }
  PLAYER_HIT_INVULN = $5A;    { 90 frames, in BOTH timers }
  PLAYER_HIT_STATE  = 8;      { knockback }
  PLAYER_HIT_LIFT   = -$40;
  PLAYER_HIT_PUSH   = $40;
  PLAYER_HIT_FX     = 8;      { spawned only out of a glide or air dash }
  SOULS_PER_LIFE    = 3;
  HUD_LIFE_X0       = 20;     { pixels }
  HUD_LIFE_STEP     = 16;
  HUD_LIFE_Y        = 16;

  { Type 36 is a falling item whose two sprites are chosen by
    EF_FLAG1C, the field Entity_MaybeDropItem writes its rarity roll into - so
    the same flag that makes Entity_TouchLife give a full refill also picks
    which sprite the thing wears on the way down.

    After landing the velocity keeps being added, and what settles it is
    Entity_TileCollideY's zero-delta guard: once the snap leaves the velocity
    at 0 the query stops reporting a collision. }
  DROP_SPRITE_COUNT = 2;
  DROP_TABLE_ADDR   = $0046BE54;
  DROP_TABLE_PTR    = $0046CE18;
  DROP_SPRITES: array[0..DROP_SPRITE_COUNT - 1] of Integer = (100, 101);

  { The effect family, types 3..13. Eleven handlers built from the same four
    moves, and each one's own TN_ constants say which of them it does. What
    the constants cannot say:

      * types 11 and 12 never call Entity_Destroy. Not a leak - they are the
        torch's flame and type 23 owns their lifetime, and anything that
        wanders off is culled by Entity_UpdateAll.
      * types 9 and 13 also run in GS_PLAY_ALT; the rest run in GS_PLAY only.
      * type 6 takes its sprite ROW from block A[1], which the explosion sets
        when it spawns the spark, so one table serves two burst colours. Type
        7 takes its row from the VARIANT.

    The tables occupy one contiguous region, with each table ending where the
    next begins. }
  T3_FRAMES = 3;  T3_TICKS = 4;   { advance when the count EXCEEDS, so every 5 }
  T3_TABLE_ADDR = $0046BC5C;
  T3_SPRITES: array[0..1, 0..T3_FRAMES - 1] of Integer =
    ((20, 21, 22),      { moving left  }
     (23, 24, 25));     { moving right }

  T4_FRAMES = 2;  T4_TICKS = 2;
  T4_TABLE_ADDR = $0046BC74;
  T4_SPRITES: array[0..T4_FRAMES - 1] of Integer = (26, 27);

  T5_FRAMES = 4;  T5_TICKS = 4;
  T5_TABLE_ADDR = $0046BC7C;
  T5_SPRITES: array[0..T5_FRAMES - 1] of Integer = (200, 201, 202, 203);

  T6_FRAMES = 4;  T6_TICKS = 8;   { every 9 - the slowest of the family }
  T6_ROWS = 2;
  T6_TABLE_ADDR = $0046BC8C;
  T6_SPRITES: array[0..T6_ROWS - 1, 0..T6_FRAMES - 1] of Integer =
    ((204, 205, 206, 207), (208, 209, 210, 211));

  T7_FRAMES = 4;  T7_TICKS = 4;
  { Two rows of four frames. Unchecked variant indexing may continue into the
    adjacent type-8 table. }
  T7_ROWS = 2;
  T7_TABLE_ADDR = $0046BCAC;
  T7_SPRITES: array[0..T7_ROWS - 1, 0..T7_FRAMES - 1] of Integer =
    ((40, 41, 42, 43), (233, 234, 235, 236));

  T9_TABLE_ADDR = $0046BCDC;
  T9_SPRITE = 212;

  T10_FRAMES = 6;  T10_TICKS = 2;
  T10_TABLE_ADDR = $0046BCE0;
  T10_SPRITES: array[0..T10_FRAMES - 1] of Integer =
    (213, 214, 215, 216, 217, 218);

  T11_FRAMES = 4;  T11_TICKS = 2;
  T11_TABLE_ADDR = $0046BCF8;
  T11_SPRITES: array[0..T11_FRAMES - 1] of Integer = (64, 65, 66, 65);
  T11_DEATH_TIMER = 2;

  T12_FRAMES = 4;  T12_TICKS = 3;
  T12_TABLE_ADDR = $0046BD08;
  T12_SPRITES: array[0..T12_FRAMES - 1] of Integer = (67, 68, 69, 70);

  { The one-shot latch types 4, 5, 6 and 7 all set on their first play frame.
    EF_STATE marks it done and the death timer is what actually removes them
    if their animation somehow does not. }
  EFFECT_LATCH_TIMER = $F0;

  { Type 13, the debris. Its state is set by whoever spawns it - see
    Entity_SpawnDebris's DEBRIS_* kinds in Entities.pas.

    State 1's sprite table depends on the STAGE TERRAIN, with no write at all
    for any terrain but 3 and 4, which leaves whatever sprite it already had.
    States 2 and 3 never end; like types 11 and 12 they rely on the off-screen
    cull.

    States 1, 2, and 3 add VEL_Y to POS_Y twice per frame, so debris falls at
    double the rate its velocity suggests. In addition,
    the gravity is applied BEFORE the first add, so the first frame moves. }
  T13_STATE_SPLASH = 0;
  T13_STATE_SHARD  = 1;
  T13_SPLASH_FRAMES = 3;  T13_SPLASH_TICKS = 8;
  T13_SHARD_FRAMES = 12;  T13_SHARD_TICKS  = 4;
  T13_GRAVITY = 2;
  T13_TERMINAL = $200;
  T13_SPLASH_TABLE_ADDR = $0046BD18;
  T13_SHARD3_TABLE_ADDR = $0046BD24;
  T13_SHARD4_TABLE_ADDR = $0046BD5C;
  T13_STATE2_TABLE_ADDR = $0046BD54;
  T13_STATE3_TABLE_ADDR = $0046BD8C;
  T13_SPLASH_SPRITES: array[0..T13_SPLASH_FRAMES - 1] of Integer =
    (219, 220, 221);
  T13_SHARD3_SPRITES: array[0..T13_SHARD_FRAMES - 1] of Integer =
    (240, 241, 240, 241, 242, 243, 242, 243, 244, 245, 244, 245);
  T13_SHARD4_SPRITES: array[0..T13_SHARD_FRAMES - 1] of Integer =
    (256, 257, 256, 257, 258, 259, 258, 259, 260, 261, 260, 261);
  { States 2 and 3 never advance their frame counter, so only element 0 of
    each is ever read. The rest of both tables is unreachable from here. }
  T13_STATE2_SPRITE = 231;
  T13_STATE3_SPRITE = 283;
  T13_TERRAIN_SHARD3 = 3;
  T13_TERRAIN_SHARD4 = 4;

  { Types 15, 21, 23, 28 and 29, the furniture - plus 17 and 19, whose arms
    are a single RET. That is not the same as having no arm, and HANDLER_ADDR
    keeps them apart from types 0, 18 and 20.

    Type 15 is the only handler that writes to the EVENT TABLE: it sets its
    own event's opcode to 9, which triggers nothing, so a thrown switch stays
    thrown without needing a progress flag.

    Type 21's EF_FACING is a signed SPEED, not a direction, negated every
    block A[1] frames, with EF_STATE choosing the axis. ParamA's 'R' letter
    writes both, so a placement carries the speed and the half-period.

    Type 23 owns types 11 and 12 - it spawns them as its flame and destroys
    them - which is why those two never destroy themselves. Both spawns
    SUBTRACT the layer delta: the children are placed after Entity_UpdateAll
    has already carried this frame's scroll into the parent, so without it
    they would be scrolled twice.

    Type 28 does nothing at all unless its variant is 0, so a variant-1
    placement is inert. }
  T15_TABLE_ADDR = $0046BE78;
  T15_SPRITES: array[0..1] of Integer = (61, 62);
  T15_SOUND = $0E;
  T15_THROWN_OPCODE = 9;

  T21_TABLE_ADDR = $0046BE80;
  T21_SPRITE = 59;
  { EF_STATE picks the axis, and the placement data is flush with these two
    values: 12 records, arg 0 taking only 0 (ten times) and 1 (twice). }
  T21_AXIS_VERTICAL   = 0;
  T21_AXIS_HORIZONTAL = 1;

  T23_TABLE_ADDR = $0046BE88;
  T23_SPRITE = 63;
  T23_FLAME_LOW_TYPE  = 11;
  T23_FLAME_HIGH_TYPE = 12;
  T23_FLAME_LOW_LIFT  = $200;    { 16 px above the torch }
  T23_FLAME_HIGH_LIFT = $2C0;    { 22 px }

  T28_FRAMES = 4;  T28_TICKS = 8;
  T28_TABLE_ADDR = $0046BE2C;
  T28_SPRITES: array[0..T28_FRAMES - 1] of Integer = (279, 280, 281, 282);
  T28_DEATH_TIMER = 2;

  T29_FRAMES = 4;
  T29_TICKS_IDLE  = 10;
  T29_TICKS_CLOSE = 4;
  T29_TABLE_ADDR = $0046BE8C;
  T29_SPRITES: array[0..T29_FRAMES - 1] of Integer = (87, 86, 88, 86);
  T29_SETTLE = $40;              { 2 px, once, on its first frame }
  T29_NEAR_SCALE_X = 3;
  T29_NEAR_SCALE_Y = 1;

  { Types 30, 31 and 37 - the first handlers to read DIFFICULTY, and they do
    it through tables indexed by it rather than by branching on it.

    Type 30 doubles its speed and halves its turn period on its first frame,
    and only on difficulty 2.

    Type 31's state 3 is a dead end in this handler: nothing here leaves it.
    The type-35 child writes state 4 back, which is why the state machine
    looks broken and is not.

    Type 37's frame counter wraps with a div AND a mod, and the quotient is
    left in EAX and returned - dead, like type 16's. }
  T30_FRAMES = 2;  T30_TICKS = 8;
  T30_TABLE_ADDR = $0046BE9C;
  T30_SPRITES: array[0..1, 0..T30_FRAMES - 1] of Integer =
    ((89, 90),      { moving left  }
     (91, 92));     { moving right }
  T30_SETTLE = $40;
  T30_HARD = 2;

  T31_FRAMES = 4;
  T31_HURT_FRAME = 4;
  T31_TICKS = 8;
  T31_TABLE_ADDR = $0046BEDC;
  T31_SPRITES: array[0..T31_HURT_FRAME] of Integer = (500, 501, 502, 501, 503);
  T31_HP_BONUS_ADDR = $0046BED0;
  T31_WAIT_ADDR     = $0046BEC4;
  T31_RATE_ADDR     = $0046BEB8;
  T31_HP_BONUS: array[0..2] of Integer = (0, 10, 20);
  T31_WAIT:     array[0..2] of Integer = (8, 6, 4);
  T31_RATE:     array[0..2] of Integer = (60, 30, 10);
  T31_WAIT_BASE   = $14;    { added to wait[diff] * HP }
  T31_ATTACK_LEN  = $B4;    { 180 frames of firing }
  T31_FIRE_EVERY  = 8;
  T31_FIRE_SOUND  = $17;
  T31_MARKER_TYPE = $23;    { 35 - the child that drives the state machine }
  T31_SHOT_TYPE   = $22;    { 34 }
  T31_RISE  = $100;         { 8 px up on spawn }
  T31_DRIFT = $80;          { 4 px left }

  { The table is SIX ints - (222, 223, 224, 225, 226, 222) - but the handler
    animates `frame := (frame + 1) mod 5`, so the sixth is unreachable. Five is
    the read count, not the extent; the sweep in --selftest-entities pins the
    extent separately so the two facts cannot be confused again. }
  T37_FRAMES = 5;  T37_TICKS = 6;
  T37_TABLE_ADDR = $0046BE5C;
  T37_SPRITES: array[0..T37_FRAMES - 1] of Integer = (222, 223, 224, 225, 226);
  T37_PUFF_TYPE = 8;
  T37_DROP      = $100;     { 8 px, once, on arrival }
  T37_TIMERS    = $3C;      { both timers armed to 60 }
  T37_GRAVITY   = 4;
  T37_TERMINAL  = $200;
  T37_LAND_SOUND = $1B;

  { Types 34 and 35, type 31's two children - and what closes the thread type
    31 leaves open, since nothing in type 31 sets its own state 4.

    Type 35 writes Angle_Between(owner, PLAYER) into its owner at the END of
    the telegraph rather than tracking it, which is why type 31's shots all
    leave along one heading however the player moves. It also destroys itself
    the moment its owner's HP reaches 0, so a parent killed mid-wind-up takes
    its telegraph with it.

    Type 34's frames advance on a difficulty divisor of 8, 10 or 12, so the
    shot animates FASTER on easy and, dying at the end of its animation, has a
    shorter range there, opposite to the other difficulty tables. }
  T34_FRAMES = 5;
  T34_TABLE_ADDR = $0046BEF0;
  T34_SPRITES: array[0..T34_FRAMES - 1] of Integer = (512, 513, 514, 515, 516);
  T34_RATE_ADDR = $0046BEAC;
  T34_RATE: array[0..2] of Integer = (8, 10, 12);
  T34_SPEED = 2;

  T35_FRAMES = 8;  T35_TICKS = 4;
  T35_TABLE_ADDR = $0046BF04;
  T35_SPRITES: array[0..T35_FRAMES - 1] of Integer =
    (504, 505, 506, 507, 508, 509, 510, 511);
  T35_MODE_WIND_UP   = 0;
  T35_MODE_WIND_DOWN = 1;
  T35_SOUND = $18;
  T35_OWNER_ATTACK = 4;
  T35_OWNER_IDLE   = 1;

  { Type 2, the player's shot. The state it carries is the WEAPON - Player.pas
    passes its WEAPONS table's ProjState straight through - and only the
    charge accelerates.

    The sparks a wall impact throws carry 1 in block A[1] for a charge shot
    and 0 otherwise, which is what selects between type 6's two sprite rows,
    so a charged impact scatters a different colour.

    Their speed multiplier is Random(2) + 1. Type 33's explosion uses
    Random(3) + 1 for the same idiom, so these are not the same burst and the
    difference is deliberate. }
  T2_STATES = 3;
  T2_FRAMES = 2;  T2_TICKS = 4;
  T2_TABLE_ADDR = $0046BC2C;
  { [state][0..1] going right, [state][2..3] going left. }
  T2_SPRITES: array[0..T2_STATES - 1, 0..3] of Integer =
    ((28, 29, 30, 31), (32, 33, 34, 35), (36, 37, 38, 39));
  T2_CHARGE_STATE = 2;
  T2_CHARGE_ACCEL = 4;
  T2_TRAIL_EVERY  = 4;    { every fifth frame - the test is `> 4` }
  T2_TRAIL_TYPE   = 7;
  T2_TRAIL_LIFT   = $80;  { 4 px above the shot }
  T2_SPARK_TYPE   = 6;
  T2_SPARKS       = 6;
  T2_SPARK_SPEED_MAX = 2; { Random(2) + 1, so 1..2 - NOT type 33's 1..3 }

  { Types 38 and 39, a turret and its shot - the same division of labour
    types 31 and 35 have, and seeing it twice is what makes it a pattern: the
    parent holds a state it cannot leave, and the CHILD moves it on.

    Type 38's state 1 counter is gated by Entity_IsOffScreen, so a turret you
    cannot see never counts down and never fires. Its facing and its sprite
    row are both its VARIANT.

    Type 39 writes its owner's state 5 only IF ITS OWN HP IS ZERO, so a shot
    that still has HP leaves its parent stuck in state 4 - which is what type
    40 relies on. }
  T38_VARIANTS = 2;
  T38_FRAMES = 4;  T38_TICKS = 4;
  T38_TABLE_ADDR = $0046BF24;
  T38_SPRITES: array[0..T38_VARIANTS - 1, 0..T38_FRAMES - 1] of Integer =
    ((110, 111, 112, 113), (106, 107, 108, 109));
  T38_WAIT_ADDR = $0046BF44;
  T38_WAIT: array[0..2] of Integer = (120, 60, 30);
  T38_SETTLE = $20;
  T38_FACING_SHIFT = 5;      { variant 0 -> heading 0, variant 1 -> heading 32 }
  T38_OFFSCREEN_MARGIN = 2;
  T38_FIRE_DELAY = $1E;      { 30 frames after the wind-up }
  T38_SHOT_TYPE = $27;       { 39 }
  T38_SHOT_AHEAD = 8;        { direction steps in front }
  T38_SHOT_LIFT = $C0;

  T39_FRAMES = 10;
  T39_CHARGE_FRAMES = 4;
  T39_FLIGHT_FIRST = 4;      { the flight loop is 4..9 }
  T39_FLIGHT_TICKS = 2;
  T39_TABLE_ADDR = $0046BF50;
  T39_SPRITES: array[0..T39_FRAMES - 1] of Integer =
    (227, 228, 229, 230, 246, 247, 248, 249, 250, 251);
  T39_WIND_ADDR  = $0046BF84;
  T39_SPEED_ADDR = $0046BF78;
  T39_WIND:  array[0..2] of Integer = (4, 2, 1);
  T39_SPEED: array[0..2] of Integer = (2, 2, 3);
  T39_LAUNCH_SOUND = $19;
  T39_OWNER_WIND_DOWN = 5;
  T39_RANGE = $3C;           { 60 frames }
  T39_PUFF_TYPE = 7;
  T39_PUFF_VARIANT = 1;

  { Type 40, the springboard - the first handler that reaches into the
    PLAYER'S ENTITY and rewrites it. Nothing here sets state 2, the launch;
    the touch handler does.

    The launch keeps the speed the player arrived with but takes the
    DIRECTION from whatever is held at that moment, so you can turn round on
    the spring. With no input the field is left alone entirely.

    Variant 1's shot is a type 39 with its HP set to 1, and only a ZERO-hp
    type 39 writes back to its owner - which is how the same shot type serves
    this parent and type 38's with different lifetimes. Its aim is a
    direction rather than an angle, and a zero is corrected to 0x20 so a shot
    fired at a player standing exactly in line still goes somewhere. }
  T40_VARIANTS = 2;
  T40_FRAMES = 4;
  T40_TABLE_ADDR = $0046BF90;
  T40_SPRITES: array[0..T40_VARIANTS - 1, 0..T40_FRAMES - 1] of Integer =
    ((123, 124, 125, 124), (192, 193, 194, 193));
  T40_COOLDOWN_ADDR = $0046BFB0;
  T40_COOLDOWN: array[0..2] of Integer = (240, 180, 180);
  T40_SETTLE = $40;
  T40_SHOOTER_VARIANT = 1;
  T40_OFFSCREEN_MARGIN = 2;
  T40_TRIGGER_SCALE_X = 8;   { a wide, flat trigger - not a touch }
  T40_TRIGGER_SCALE_Y = 2;
  T40_SHOT_TYPE = $27;       { 39, but with HP 1 so it never frees this parent }
  T40_SHOT_LIFT = $A0;
  T40_AIM_SHIFT = 5;
  T40_AIM_ZERO = $20;        { a shot straight at the player still goes right }
  T40_LAUNCH_VY = -$D0;
  T40_LAUNCH_SOUND = $1A;
  T40_BOUNCE_FRAMES = 3;  T40_BOUNCE_TICKS = 4;  T40_BOUNCE_CYCLES = 4;
  T40_BOUNCE_TIMER = $78;

  { Type 41, the hopper. On HARD ONLY it doubles its speed on its first frame
    - the same one-line scaling type 30 has. Like type 38, its idle counts
    only while on screen, so a hopper off screen is frozen mid-crouch rather
    than hopping in place. }
  T41_FRAMES = 4;  T41_TICKS = 6;
  T41_TABLE_ADDR = $0046BFBC;
  T41_SPRITES: array[0..5] of Integer = (126, 127, 128, 127, 129, 130);
  T41_WAIT_ADDR = $0046BFD4;
  T41_WAIT: array[0..2] of Integer = (30, 20, 10);
  T41_SETTLE = $20;
  T41_HARD = 2;
  T41_OFFSCREEN_MARGIN = 2;
  T41_JUMP_SOUND = $21;
  T41_JUMP_VY = -$60;
  T41_CROUCH_FRAME = 4;
  T41_AIR_FRAME = 5;
  T41_CROUCH_TICKS = 4;
  T41_GRAVITY = 4;
  T41_TERMINAL = $200;

  { Type 42, a boss. Its timings scale with its own HP as well as with the
    difficulty, so a boss that has taken damage acts faster - a difficulty
    curve inside a single fight.

    EF_SHOTS, normally an owner's live-shot count, is reused here as the
    recovery counter. }
  T42_FRAMES = 4;  T42_TICKS = 8;
  T42_TABLE_ADDR = $0046C010;
  T42_SPRITES: array[0..6] of Integer = (500, 501, 502, 501, 502, 503, 504);
  T42_HP_BONUS_ADDR = $0046C004;
  T42_HP_BONUS: array[0..2] of Integer = (0, 20, 40);
  T42_RISE_LEN_ADDR = $0046BFE0;
  T42_RISE_LEN: array[0..2] of Integer = (120, 60, 30);
  T42_SHOTS_ADDR = $0046BFF8;
  T42_SHOTS: array[0..2] of Integer = (1, 3, 5);   { plus one - so 2, 4 or 6 }
  T42_ANGLES_ADDR = $0046C05C;
  T42_ANGLES: array[0..5] of Integer = (-1, 1, -2, 2, -3, 3);
  T42_RECOVER_ADDR = $0046BFEC;
  T42_RECOVER: array[0..2] of Integer = (30, 20, 10);
  T42_DROP = $100;
  T42_SPEED = $20;
  T42_BOB_EVERY = 4;
  T42_PATROL_BASE = $78;      { HP * 10 + this }
  T42_PATROL_SOUND = $23;
  T42_LAND_SOUND = 4;
  { Rise and retreat velocities are signed fixed-point values. }
  T42_RISE_VY = -$40;
  T42_RETREAT_VY = -$60;
  T42_GRAVITY = 4;
  T42_TERMINAL = $200;
  T42_SHOT_TYPE = $2C;        { 44 }
  T42_SHOT_LIFT = $400;
  T42_ANGLE_SHIFT = 5;
  T42_FALL_FRAME = 4;
  T42_LAND_FRAME = 5;
  T42_LAND_LAST  = 6;
  T42_RECOVER_BASE = $1E;
  T42_RECOVERIES = 2;         { every third one retreats }
  T42_RETREAT_STEP = $20;
  T42_RETREAT_LEN = $3C;

  { Types 43 and 44. Type 43 is four instructions and one of them is the
    point:

        EF_VULN_KIND := variant + 0x5A

    which lands exactly on the armour block Entity_TakeProjectileHits knows,
    0x5A..0x5D. One entity type covers all four armours and the placement's
    variant picks which - which is why those four constants sit contiguously
    rather than scattered like the other kinds. Written EVERY frame, not once.

    Type 44 has no Entity_Destroy at all; like types 9, 11 and 12 it relies on
    the off-screen cull. }
  T43_VARIANTS = 4;
  T43_TABLE_ADDR = $0046C02C;
  T43_SPRITES: array[0..T43_VARIANTS - 1] of Integer = (121, 122, 179, 442);
  T43_VULN_BASE = $5A;      { VULN_ARMOUR_1 - see the block above }

  T44_FRAMES = 8;  T44_TICKS = 2;
  T44_TABLE_ADDR = $0046C03C;
  T44_SPRITES: array[0..T44_FRAMES - 1] of Integer =
    (505, 506, 507, 508, 509, 510, 511, 512);
  { Launch velocity is -80; type 42's own jump uses -176. }
  T44_LAUNCH_VY = -$50;
  T44_GRAVITY = 2;
  T44_TERMINAL = $200;

  { Types 45 and 46. Type 45 is the only handler that reads EF_RIDDEN, the
    flag Entity_SolidCollideY sets when something stands on a solid - and that
    flag is cleared at the END of every frame whatever state it is in, so it
    is a one-frame signal the collision has to re-set to keep the count going.
    Its shake threshold SUBTRACTS a difficulty figure from the placement's own
    count, so a harder game crumbles it sooner.

    Type 46 wakes on horizontal pixel distance, and an EASIER game wakes it
    LATER. Its initial heading is Random(64) - the second use of the RNG
    outside the debris - so a room full of them does not move in lockstep. }
  T45_FRAMES = 5;  T45_TICKS = 8;
  T45_TABLE_ADDR = $0046C074;
  T45_SPRITES: array[0..T45_FRAMES - 1] of Integer = (131, 132, 133, 134, 133);
  T45_TOUGH_ADDR = $0046C088;
  T45_TOUGH: array[0..2] of Integer = (0, 2, 4);
  T45_SHAKE_FIRST = 1;      { the loop is frames 1..4 }
  T45_BREAK_SOUND = $1C;
  T45_GONE_FRAMES = $3C;

  T46_FRAMES = 4;  T46_TICKS = 4;
  T46_TABLE_ADDR = $0046C094;
  T46_SPRITES: array[0..4] of Integer = (136, 137, 138, 137, 135);
  T46_SLEEP_FRAME = 4;
  T46_RANGE_ADDR = $0046C0A8;
  T46_TURN_ADDR  = $0046C0B4;
  T46_SPEED_ADDR = $0046C0C0;
  T46_RANGE: array[0..2] of Integer = (64, 80, 128);   { easy wakes LATER }
  T46_TURN:  array[0..2] of Integer = (4, 4, 2);
  T46_SPEED: array[0..2] of Integer = (2, 3, 4);
  T46_RISE = $A0;
  T46_WAKE_SOUND = $1D;
  T46_TURN_TIMER = 1;       { Steer's timer slot }

  { Type 47, the lobber. Its two difficulty tables run in OPPOSITE directions
    - the wait before winding up is 120, 60, 60 and the rest afterwards is
    180, 120, 60. Both make it fire more often, but they were tuned as
    separate numbers rather than one.

    It reads only the first two entries of a four-int angle table - the loop
    is a `do ... while (--n)` from 2 - so the other two are unreachable from
    this handler. }
  T47_FRAMES = 2;  T47_TICKS = 8;
  T47_TABLE_ADDR = $0046C0CC;
  T47_SPRITES: array[0..4] of Integer = (139, 140, 141, 142, 143);
  T47_WAIT_ADDR = $0046C0E0;
  T47_REST_ADDR = $0046C0EC;
  T47_ANGLES_ADDR = $0046C108;
  T47_WAIT: array[0..2] of Integer = (120, 60, 60);
  T47_REST: array[0..2] of Integer = (180, 120, 60);
  T47_ANGLES: array[0..1] of Integer = (-1, 1);
  T47_WIND_FIRST = 1;
  T47_WIND_LAST = 3;
  T47_OFFSCREEN_MARGIN = 2;
  T47_SHOT_TYPE = $30;      { 48 }
  T47_SHOT_LIFT = $200;
  T47_SHOT_VY = -$40;
  T47_ANGLE_SHIFT = 5;
  T47_FIRE_SOUND = $1E;

  { Type 48, the bouncing shot. Each rebound is (bounces left + 1) * -0x10,
    so the arc decays out of the counter and there is no separate decay term.

    On the SECOND-TO-LAST bounce it arms EF_DEATH_TIMER to 3600 frames, far
    longer than it can survive its remaining bounce. Entity_UpdateAll uses
    that field's parity for the damage flicker, so the practical effect is
    that the ball starts BLINKING on its last bounce, not that it times out.

    It copies field 0x2C into its velocity on any frame that field is
    non-zero, then clears it. Entity_Spawn zeroes 0x2C and type 47 sets
    EF_VEL_X directly, so nothing in the shipped game ever puts anything
    there. Reproduced because the read is real. }
  T48_FRAMES = 4;  T48_TICKS = 8;
  T48_TABLE_ADDR = $0046C0F8;
  T48_SPRITES: array[0..T48_FRAMES - 1] of Integer = (237, 238, 239, 238);
  T48_BOUNCES = 4;
  T48_GRAVITY = 2;
  T48_TERMINAL = $200;
  T48_BOUNCE_SOUND = $21;
  T48_REBOUND_STEP = -$10;
  T48_BLINK_TIMER = $E10;   { armed on the second-to-last bounce }
  T48_HANDOFF = $2C;        { the one-shot velocity slot }

  { Type 49, the diver. Its trigger distance runs the ordinary way round -
    HARDER sees further - and above easy it also AIMS, because that write sits
    inside `if difficulty > 0`; on easy it dives straight down.

    It calls Entity_SpawnDebris twice, at the start and end of the dive, which
    is the only use of that function outside a death: the debris doubles as a
    dust puff here.

    It clears EF_BLOCK_A[1] and EF_CHILD_B when the dive starts, and neither
    is read anywhere in this handler. }
  T49_FRAMES = 2;  T49_TICKS = $10;
  T49_TABLE_ADDR = $0046C118;
  T49_SPRITES: array[0..3] of Integer = (144, 145, 146, 147);
  T49_RANGE_ADDR = $0046C128;
  T49_REST_ADDR  = $0046C134;
  T49_RANGE: array[0..2] of Integer = (64, 128, 256);   { harder sees further }
  T49_REST:  array[0..2] of Integer = (120, 120, 60);
  T49_BOB_SHIFT = 2;        { a quarter of the heading's Y component }
  T49_DIVE_VY = -$C0;
  T49_GRAVITY = 4;
  T49_DIVE_END = $BF;
  T49_RISING_FRAME = 2;
  T49_FALLING_FRAME = 3;
  T49_AIM_SHIFT = 5;

  { Type 50, the opener. While it is open it REWRITES ITS OWN EF_VULN_KIND,
    so the window in which it can be hurt is part of the animation rather than
    a property of the type.

    Its states are 1, 2, 3, 5 and 6 - there is no 4, and nothing here moves it
    from 3 to 5 either; the type-39 shot it spawns does, the same parent-child
    arrangement types 31/35 and 38/39 use.

    On EASY it starts by SUBTRACTING 2 from its own EF_HP - the only handler
    that makes itself weaker rather than the difficulty making it stronger. }
  T50_FRAMES = 4;  T50_TICKS = 8;
  T50_TABLE_ADDR = $0046C140;
  T50_SPRITES: array[0..5] of Integer = (148, 149, 150, 149, 151, 152);
  T50_PATROL_ADDR = $0046C158;
  T50_HOLD_ADDR   = $0046C164;
  T50_PATROL: array[0..2] of Integer = (60, 60, 60);   { deliberately flat }
  T50_HOLD:   array[0..2] of Integer = (120, 60, 60);
  T50_EASY_HP_PENALTY = -2;
  T50_OPEN_FIRST = 4;
  T50_OPEN_LAST  = 5;
  T50_OFFSCREEN_MARGIN = 2;
  T50_SHOT_TYPE = $27;      { 39 }
  T50_SHOT_SPEED = 2;
  T50_VULN_OPEN    = 1;
  T50_VULN_CLOSING = 2;

  { Types 51 and 53. Neither has an end: type 51 homes until something kills
    it, and type 53 runs until it leaves the screen.

    Type 53's sprite table is two rows of FIVE, so its stride is 0x14 rather
    than the usual 0x10. }
  T51_FRAMES = 4;  T51_TICKS = 8;
  T51_TABLE_ADDR = $0046C170;
  T51_SPRITES: array[0..T51_FRAMES - 1] of Integer = (153, 154, 155, 154);
  T51_TURN_TIMER = 1;
  T51_TURN_RELOAD = 6;
  T51_DEATH_TIMER = 2;

  T53_ROW = 5;
  T53_WIND_LAST = 2;
  T53_RUN_FIRST = 3;
  T53_RUN_LAST = 4;
  T53_TICKS = 4;
  T53_TABLE_ADDR = $0046C1D0;
  T53_SPRITES: array[0..1, 0..T53_ROW - 1] of Integer =
    ((512, 513, 514, 508, 509),      { going left  }
     (512, 513, 514, 510, 511));     { going right }
  T53_CHARGE_SOUND = 7;

  { Type 56, the burst trap. Its aim takes Angle_Between(self, player) and
    adds a difficulty SKEW of 0, -4 or -8, so harder settings LEAD the shot
    rather than aiming straight at the player.

    The heading wrap is written `next := aim + 4; if next > 63 then next :=
    aim - 0x3C` - a subtraction of 60 from the PREVIOUS value rather than a
    mask on the new one. It is exactly equivalent to (aim + 4) mod 64 for
    every aim in 0..63.

    The fuse lives in EF_TIMER, which Entity_UpdateAll counts down, so this
    handler only watches for zero. }
  T56_FRAMES = 3;
  T56_TABLE_ADDR = $0046C268;
  T56_SPRITES: array[0..T56_FRAMES - 1] of Integer = (156, 157, 158);
  T56_SKEW_ADDR  = $0046C274;
  T56_COUNT_ADDR = $0046C280;
  T56_SPEED_ADDR = $0046C28C;
  T56_SKEW:  array[0..2] of Integer = (0, -4, -8);   { harder LEADS the shot }
  T56_COUNT: array[0..2] of Integer = (0, 2, 4);     { plus one }
  T56_SPEED: array[0..2] of Integer = (2, 2, 3);
  T56_TRIGGER_SCALE_X = 5;
  T56_TRIGGER_SCALE_Y = 2;
  T56_FUSE = 4;
  T56_SHOT_TYPE = $39;      { 57 }
  T56_FAN_STEP = 4;
  T56_FAN_WRAP = $3C;       { subtracted from the previous heading, not a mask }

  { Type 59, the riser. Its wake range is a bare literal - the only proximity
    test in the game that is not difficulty-keyed. It leaves the rise the
    moment its velocity turns positive, which is the apex rather than a fixed
    time, and takes Angle_Between ONCE on entering the flight, so it commits
    to a heading at the top of its arc and cannot correct.

    Nothing ends it. Once flying it flies until it is culled. }
  T59_TABLE_ADDR = $0046C300;
  T59_SPRITES: array[0..5] of Integer = (270, 162, 163, 164, 165, 166);
  T59_SPEED_ADDR = $0046C318;
  T59_SPEED: array[0..2] of Integer = (1, 2, 3);
  T59_WAKE_RANGE = $50;     { a bare literal - not difficulty-keyed }
  T59_RISE_VY = -$80;
  T59_GRAVITY = 2;
  T59_HANG_TICKS = 8;
  T59_FLY_TICKS = 4;
  T59_FLY_FIRST = 3;
  T59_FLY_LAST = 5;
  T59_RISE_FRAME = 1;
  T59_HANG_FRAME = 2;

  { Type 52, the boss. Two things the code does not say for itself:

      * it REWRITES ITS OWN EF_INSET_PCT_Y - 70 entering the circle, 20
        entering the dive - and Entity_UpdateAll turns that back into a
        hitbox inset every frame, so it is a small target while circling and
        a large one while diving. Type 50 does the same with EF_VULN_KIND.
      * its HP table is NEGATIVE on every difficulty and applied once at
        spawn, so the type table carries the HARD figure and each easier
        setting subtracts from it. Type 50 does this too, but only on easy.

    Only on hard does it re-aim before circling, and a zero heading is forced
    to +0x80 so it can never stall. }
  T52_FRAMES = 2;  T52_TICKS = 8;
  T52_TABLE_ADDR = $0046C1B0;
  T52_SPRITES: array[0..1, 0..3] of Integer =
    ((500, 501, 502, 506),        { going left  }
     (503, 504, 505, 507));       { going right }
  T52_HP_ADDR     = $0046C180;
  T52_TIMING_ADDR = $0046C1A4;
  T52_COUNT_ADDR  = $0046C18C;
  T52_SPEED_ADDR  = $0046C198;
  T52_HP:     array[0..2] of Integer = (-30, -20, -10);  { all negative }
  T52_TIMING: array[0..2] of Integer = (120, 60, 30);
  T52_COUNT:  array[0..2] of Integer = (2, 3, 4);
  T52_SPEED:  array[0..2] of Integer = (2, 3, 3);
  T52_ENTRY_DROP = $1E0;    { it starts by falling into view }
  T52_ENTRY_VX = -$80;
  T52_HP_PACE_DIV = $28;    { hp div 40 ... }
  T52_HP_PACE_MUL = 100;    { ... times 100, added to the wait }
  T52_INSET_CIRCLE = 70;    { a small target while it circles ... }
  T52_INSET_DIVE = 20;      { ... and a large one while it dives }
  T52_CIRCLE_FRAME = 2;
  T52_DIVE_FRAME = 3;
  T52_TURN_STEP = $10;      { a quarter turn per frame }
  T52_CIRCLE_TICKS = $3C;
  T52_DIVE_VY = -$20;
  T52_GRAVITY = 2;
  T52_LAND_VY = $1F;
  T52_CHARGE_VX = $80;      { forced when the aim comes out zero }
  T52_SUMMON_BEAT = 3;      { the beat on which it summons instead of diving }
  T52_MINION_TYPE = $35;    { 53, the charger }
  T52_MINION_AHEAD = $600;  { 48 px }
  T52_MINION_BELOW = $A0;   { 5 px }
  T52_SND_SUMMON = $24;
  T52_SND_SPAWN  = $25;
  T52_SND_LAND   = 4;

  { Types 54 and 55, the second boss and its fireball. Type 55 MULTIPLIES both
    velocity components by difficulty + 1 EVERY FRAME, so above easy it
    compounds between the frames on which the steer reloads. Kept as written,
    as is the order the two jitter randoms are drawn in - see the handler. }
  T54_FRAMES = 2;  T54_TICKS = $10;
  T54_TABLE_ADDR = $0046C204;
  T54_SPRITES: array[0..T54_FRAMES - 1] of Integer = (500, 501);
  T54_HP_ADDR = $0046C1F8;
  T54_HP: array[0..2] of Integer = (-30, -20, -10);   { type 52's numbers }
  T54_HOP_ADDR = $0046C20C;
  T54_HOPS = 4;
  T54_HOP: array[0..T54_HOPS - 1, 0..1] of Integer =
    ((160, 0), (-320, 0), (160, -96), (0, 96));       { sums to (0, 0) }
  T54_HOP_SCALE = $20;      { a pixel per unit }
  T54_HP_PACE_DIV = 2;      { hp div 2 ... }
  T54_HP_PACE_MUL = 60;     { ... times 60 ... }
  T54_HP_PACE_ADD = 60;     { ... plus 60 }
  T54_BLINK = $1E;          { both timers, entering and leaving the blink }
  T54_HOLD = $3C;
  T54_SHOT_TYPE = $37;      { 55 }
  T54_SND_BLINK = $1C;

  T55_FLY_FRAMES = 8;   T55_FLY_TICKS = 2;
  T55_TRAIL_FRAMES = 7; T55_TRAIL_TICKS = 5;
  T55_FLY_TABLE_ADDR = $0046C22C;
  T55_FLY_SPRITES: array[0..T55_FLY_FRAMES - 1] of Integer =
    (502, 503, 504, 505, 506, 507, 508, 509);
  T55_TRAIL_TABLE_ADDR = $0046C24C;
  T55_TRAIL_SPRITES: array[0..T55_TRAIL_FRAMES - 1] of Integer =
    (510, 511, 512, 511, 510, 511, 512);
  T55_TURN_TIMER = 1;
  T55_TURN_RELOAD = 2;
  T55_HOMING_UNTIL = $F0;   { EF_SHOTS - the homing stops here ... }
  T55_LIFETIME = $F0;       { ... and EF_BLOCK_B[4] ends it one frame later }
  T55_TRAIL_EVERY = $10;
  T55_TRAIL_SPREAD = $10;   { RandomBelow(16) - 8, so eight pixels either way }
  T55_TRAIL_CENTRE = 8;
  T55_TRAIL_SCALE = $20;
  T55_TRAIL_DEPTH = 3;
  T55_TRAIL_BLINK = 2;
  T55_TRAIL_TIMER = 2;
  T55_SELF_TYPE = $37;      { 55 - the trail is another one of these }
  T55_SND_LOOP = $26;       { on the frame the animation wraps to 0 }

  { Types 58 and 60. Type 58's setup runs BEFORE Entity_UpdateDying, so one
    killed on its spawn frame still takes its 5-pixel drop. Kept in that order.

    Type 60's `if EF_HP < 11 then EF_HP := 3` is a WRITE, not a clamp: an
    enemy on 10 hp loses 7 and one on 1 hp GAINS 2. Its only difficulty-keyed
    number is the charge speed AFTER enraging, so difficulty changes nothing
    about it until it has been hurt. Its two ledge probes are the same call
    with a different vertical delta - a wall ahead, and no floor one tile
    down. }
  T58_FRAMES = 2;           { 0 and 1 while awake; 2 is the dormant sprite }
  T58_TICKS = 4;
  T58_TABLE_ADDR = $0046C2F4;
  T58_SPRITES: array[0..2] of Integer = (160, 161, 159);
  T58_SLEEP_FRAME = 2;
  T58_SETTLE = $A0;         { 5 px down when it spawns ... }
  T58_RISE = -$60;          { ... and 3 px up when it wakes }
  T58_TRIGGER_SCALE = 3;
  T58_SND_WAKE = $27;

  T60_FRAMES = 2;
  T60_TABLE_ADDR = $0046C324;
  T60_SPRITES: array[0..1, 0..3] of Integer =
    ((167, 168, 169, 170),        { going left  }
     (171, 172, 173, 174));       { going right }
  T60_SPEED_ADDR = $0046C344;
  T60_TURN_ADDR  = $0046C35C;
  T60_RAGE_ADDR  = $0046C350;
  T60_SPEED: array[0..2] of Integer = (1, 1, 1);        { flat }
  T60_TURN:  array[0..2] of Integer = (180, 180, 180);  { flat }
  T60_RAGE:  array[0..2] of Integer = (3, 4, 5);        { the only one keyed }
  T60_SPEED_SHIFT = 4;
  T60_SETTLE = $20;
  T60_RAGE_BELOW = $B;      { hp under 11 ... }
  T60_RAGE_HP = 3;          { ... is SET to 3, up or down }
  T60_RAGE_VARIANT = 2;     { the second pair of frames in each row }
  T60_PUFF_LIFT = $20;
  T60_ANIM_BASE = $C;       { (state - 1) * -6 + 12, so 12 calm and 6 enraged }
  T60_ANIM_STEP = -6;
  T60_LEDGE_PROBE = $400;   { one tile down - no floor there means turn }

  { Type 57, four entities wearing one handler, switched on EF_VARIANT with
    no line shared between the branches: type 56's shot, type 63's skimmer,
    type 65's homing fireball, type 67's egg.

    Variant 1 reads the SAME eight-int table two ways - state 0 as two rows of
    four, picking by the sign of EF_VEL_X, state 1 as one linear walk.

    Variant 2 is type 55's state 0 down to the constants, including the
    multiply by difficulty + 1 every frame.

    Variant 3's bounce is worth reading twice. On the frame it hits a wall it
    writes the EXACT distance to that wall into EF_VEL_X so it lands flush,
    which would throw the reversed velocity away - so the reversal is parked
    in EF_PARKED_VEL and picked up the next frame. It bursts into a type 68
    spawned as an ACTOR in EF_STATE 3, which is where Entity_UpdateAll's
    type-68-in-state-3 special case comes from. }
  T57_V0_FRAMES = 4;  T57_V0_TICKS = 2;
  T57_V0_TABLE_ADDR = $0046C298;
  T57_V0_SPRITES: array[0..T57_V0_FRAMES - 1] of Integer =
    (252, 253, 254, 255);

  T57_V1_FRAMES = 8;  T57_V1_TICKS = 2;
  T57_V1_TABLE_ADDR = $0046C2A8;
  { Read as two rows of four in state 0 and as one run of eight in state 1. }
  T57_V1_SPRITES: array[0..T57_V1_FRAMES - 1] of Integer =
    (262, 263, 264, 265, 266, 267, 268, 269);
  T57_V1_ROW = 4;
  T57_V1_HOP = -$40;
  T57_V1_GRAVITY = 2;
  T57_V1_TERMINAL = $200;
  T57_V1_SND_HIT = $F;

  T57_V2_FRAMES = 8;  T57_V2_TICKS = 2;
  T57_V2_TABLE_ADDR = $0046C2C8;
  T57_V2_SPRITES: array[0..T57_V2_FRAMES - 1] of Integer =
    (271, 272, 273, 274, 275, 276, 277, 278);
  T57_V2_TURN_TIMER = 1;
  T57_V2_TURN_RELOAD = 2;
  T57_V2_HOMING_UNTIL = $F0;
  T57_V2_LIFETIME = $F0;
  T57_V2_TRAIL_EVERY = 8;
  T57_V2_TRAIL_TYPE = $1C;   { 28 }
  T57_V2_END_TYPE = 7;
  T57_V2_END_VARIANT = 1;
  T57_V2_SND_LOOP = $26;

  T57_V3_FRAMES = 3;  T57_V3_TICKS = 2;
  T57_V3_ROCK_FRAMES = 2;
  T57_V3_TABLE_ADDR = $0046C2E8;
  T57_V3_SPRITES: array[0..T57_V3_FRAMES - 1] of Integer = (288, 289, 290);
  T57_V3_HATCH_ADDR = $0046C460;
  T57_V3_HATCH: array[0..2] of Integer = (8, 4, 1);   { hard hatches at once }
  T57_V3_HOPS = 6;
  T57_V3_HOP_UNIT = -$10;
  T57_V3_GRAVITY = 4;
  T57_V3_TERMINAL = $200;
  T57_V3_SND_LAND = $1B;
  T57_V3_SND_HATCH = $31;
  T57_V3_BURST = 8;
  T57_V3_BURST_TYPE = 6;
  T57_V3_SPEED_SPREAD = 2;   { RandomBelow(2) + 3, so 3 or 4 half-components }
  T57_V3_SPEED_BASE = 3;
  T57_V3_HATCHLING = $44;    { 68 - the type Entity_UpdateAll touches twice }
  T57_V3_HATCHLING_STATE = 3;
  T57_V3_HATCHLING_HP = 8;
  T57_V3_HATCHLING_DEPTH = 5;

  { TYPE 61 runs AWAY from you, and the argument order below is how:

        Compare(player.x, self.x) * 4

    Compare(A, B) is the sign of B - A, so this is the sign of self.x -
    player.x, accelerating it further from the player. Every other chaser in
    the game writes the arguments the other way round. It is not a
    transcription slip - type 67 flees an egg with the identical expression,
    and two binaries agree byte for byte here (tools/bindiff.py).

    It also zeroes its OWN EF_HP wherever its box overlaps the player's, in
    both states, so catching it is what kills it. }
  T61_FRAMES = 2;  T61_TICKS = 2;
  T61_TABLE_ADDR = $0046C368;
  T61_SPRITES: array[0..3] of Integer = (175, 176, 177, 178);
  T61_SPEED_ADDR = $0046C378;
  T61_SPEED: array[0..2] of Integer = (4, 6, 8);
  T61_IDLE_TURN = $10;      { a quarter turn a frame - it sways }
  T61_WAKE_X = 6;           { wide and flat }
  T61_WAKE_Y = 2;
  T61_RUN_FIRST = 2;
  T61_RUN_LAST = 3;
  T61_RUN_TICKS = 3;
  T61_ACCEL = 4;
  T61_SPEED_SCALE = $10;
  T61_GRAVITY = 2;
  T61_TERMINAL = $200;
  T61_SQUEAK_EVERY = $1E;
  T61_TOUCH_SCALE = 1;
  T61_SND_SQUEAK = $29;

  T62_FRAMES = 2;  T62_TICKS = 8;
  T62_TABLE_ADDR = $0046C384;
  T62_SPRITES: array[0..1, 0..1] of Integer =
    ((180, 181),      { going left  }
     (182, 183));     { going right }
  T62_SPEED_ADDR = $0046C394;
  T62_SPEED: array[0..2] of Integer = (1, 2, 4);
  T62_SPEED_SCALE = $10;
  { Backwards along its own line of travel, so a stack of them placed on one
    spot with variants 0, 1, 2... spreads into a column all marching the same
    way. The variant is a rank in a queue. }
  T62_RANK_STEP = $400;
  T62_LEDGE_PROBE = $400;
  { Rewritten EVERY FRAME from the geometry. Type 50 also changes its own
    vulnerability, but as part of an animation; this is the only enemy whose
    weak side depends on where the PLAYER is standing. }
  T62_VULN_AWAY = 1;
  T62_VULN_TOWARDS = 2;

  { Types 63 and 64. Type 63 fires on an EQUALITY test against the fire frame
    rather than a threshold, and only while already moving TOWARDS the player
    - the same expression type 62 uses to pick its vulnerability, written out
    again rather than shared. Leaving state 2 negates EF_VEL_X, so it always
    walks back the way it came.

    Type 64's wait threshold is WAIT[difficulty] * EF_VARIANT, so a row of
    them with variants 1, 2, 3 drops in sequence and a variant 0 drops at
    once. Its animation ticks at the top of the handler, outside every state,
    so it flaps at the same rate whatever it is doing. }
  T63_FRAMES = 2;  T63_TICKS = 8;
  T63_TABLE_ADDR = $0046C3A0;
  T63_SPRITES: array[0..1, 0..3] of Integer =
    ((184, 185, 186, 187),        { going left  }
     (188, 189, 190, 191));       { going right }
  T63_FIRE_AT_ADDR  = $0046C3CC;
  T63_SHOT_SPD_ADDR = $0046C3C0;
  T63_RECOVER_ADDR  = $0046C3D8;
  T63_COOLDOWN_ADDR = $0046C3E4;
  T63_FIRE_AT:  array[0..2] of Integer = (40, 40, 20);
  T63_SHOT_SPD: array[0..2] of Integer = (2, 3, 3);
  T63_RECOVER:  array[0..2] of Integer = (60, 60, 30);
  T63_COOLDOWN: array[0..2] of Integer = (120, 120, 60);
  T63_WALK_SPEED = $20;
  T63_LEDGE_PROBE = $400;
  T63_WAKE_X = 6;
  T63_WAKE_Y = 2;
  T63_AIM_FRAME = 2;
  T63_FIRE_FRAME = 3;
  T63_SHOT_TYPE = $39;      { 57 ... }
  T63_SHOT_VARIANT = 1;     { ... variant 1, the skimmer }
  T63_SHOT_AHEAD = $C;      { twelve times its own velocity }
  T63_SHOT_DROP = $80;      { 4 px below }
  T63_SND_FIRE = $2B;

  T64_FRAMES = 2;  T64_TICKS = 2;
  T64_TABLE_ADDR = $0046C3F0;
  T64_SPRITES: array[0..T64_FRAMES - 1] of Integer = (420, 421);
  T64_WAIT_ADDR = $0046C3F8;
  T64_REST_ADDR = $0046C404;
  T64_RISE_ADDR = $0046C410;
  T64_WAIT: array[0..2] of Integer = (30, 20, 10);   { times EF_VARIANT }
  T64_REST: array[0..2] of Integer = (60, 40, 20);
  T64_RISE: array[0..2] of Integer = (2, 3, 4);
  T64_NUDGE = $200;         { 16 px right, once, on its first frame }
  T64_GRAVITY = 4;
  T64_TERMINAL = $200;
  T64_RISE_SCALE = -$10;
  T64_WAVE_TYPE = 3;
  T64_WAVE_OUT = $300;      { 24 px to each side ... }
  T64_WAVE_DROP = $100;     { ... and 8 px down }
  T64_WAVE_SPEED = $20;
  T64_SND_SLAM = $2A;

  { Types 65 and 66. Type 65 is the only enemy that reads the INPUT STATE: it
    will not start until ATTACK is pressed while the player stands in its box.
    It writes EF_VULN_KIND and EF_HIT_SOUND onto the type 57 it fires, which
    no other spawner does, so its fireball can be hurt. Above easy it gives
    ITSELF 2 more HP - the opposite direction from types 50, 52 and 54.

    Type 66's two sign tests are written differently - the anchor asks
    Compare(EF_FACING, 0) < 1 and the satellite < 0 - so at EF_FACING = 0 both
    still advance. The asymmetry is real and harmless. }
  T65_FRAMES = 2;  T65_TICKS = 4;
  T65_TABLE_ADDR = $0046C41C;
  T65_SPRITES: array[0..T65_FRAMES - 1] of Integer = (195, 196);
  T65_HOP_ADDR = $0046C424;
  T65_HOPS = 2;
  T65_HOP: array[0..T65_HOPS - 1] of Integer = (-96, 96);
  T65_HOP_SCALE = $20;
  T65_HARD_HP_BONUS = 2;    { it gives ITSELF hp - the others take it away }
  T65_WAKE_X = 10;
  T65_WAKE_Y = 2;
  T65_ATTACK_BUTTON = 1;
  T65_BLINK = $1E;
  T65_HOLD = $3C;
  T65_AIM_SHIFT = 5;
  T65_SHOT_TYPE = $39;      { 57 ... }
  T65_SHOT_VARIANT = 2;     { ... variant 2, the homing fireball }
  T65_SHOT_SPEED = $40;
  T65_SHOT_VULN = 6;
  T65_SHOT_HIT_SOUND = 2;
  T65_BOB_TICKS = 2;
  T65_SND_BLINK = $1C;

  T66_ANCHOR = 0;
  T66_SATELLITE = 1;
  T66_V0_FRAMES = 3;
  T66_V0_TABLE_ADDR = $0046C42C;
  T66_V0_SPRITES: array[0..T66_V0_FRAMES - 1] of Integer = (197, 198, 199);
  T66_V1_FRAMES = 2;  T66_V1_TICKS = 2;
  T66_V1_TABLE_ADDR = $0046C438;
  T66_V1_SPRITES: array[0..T66_V1_FRAMES - 1] of Integer = (490, 491);
  T66_SELF_TYPE = $42;      { 66 - the anchor spawns another of itself }
  T66_LIFT_UNIT = -$A0;     { facing * period * this, above the anchor }
  T66_ANCHOR_DEPTH = 2;
  T66_SND_LAP = $2E;        { on every wrap of the orbit }

  { Types 67 and 68, and the last of type 57. With type 67's egg, every
    variant of type 57 has an owner - 56's burst, 63's skimmer, 65's fireball,
    and 67's egg, so the shared handler supports four distinct emitters.

    Type 67's retreat uses Compare(player.x, self.x), the AWAY arithmetic that
    looks like a slip in type 61. Two handlers writing it settles that it is
    not a typo.

    Type 68 rewrites BOTH its own hitbox insets from a per-FRAME table while
    it animates in state 3. Types 50 and 52 also modify their own hitbox, but
    from a state; this is the only one driving it frame by frame, and it is
    why Entity_UpdateAll gives a state-3 type 68 a SECOND Entity_PlayerTouch -
    the window to catch it is the animation.

    Nothing here sets state 4; whatever catches it does. Its landing is the
    only Entity_Destroy in any handler translated so far that passes True, so
    it is the only one that pays out loot. }
  T67_FRAMES = 4;  T67_TICKS = 4;
  T67_TABLE_ADDR = $0046C440;
  T67_SPRITES: array[0..4] of Integer = (438, 439, 440, 439, 441);
  T67_LAY_FRAME = 4;        { the fifth entry, outside the walk loop }
  T67_RANGE_ADDR    = $0046C46C;
  T67_COOLDOWN_ADDR = $0046C454;
  T67_RANGE:    array[0..2] of Integer = (6, 8, 10);   { harder sees further }
  T67_COOLDOWN: array[0..2] of Integer = (120, 30, 10);
  T67_WAKE_Y = 4;
  T67_WALK_SHIFT = 4;
  T67_BOLT_SHIFT = 6;       { the sprint is sixteen times the walk }
  T67_FRICTION = 1;
  T67_LEDGE_PROBE = $400;
  T67_LAY_AT = 8;
  T67_LAY_END = $10;
  T67_EGG_TYPE = $39;       { 57 ... }
  T67_EGG_VARIANT = 3;      { ... variant 3 }
  T67_EGG_LIFT = $180;      { 12 px above it }
  T67_EGG_VY = -$40;
  T67_SND_LAY = $2B;

  T68_FRAMES = 8;  T68_TICKS = 4;
  T68_TABLE_ADDR = $0046C478;
  T68_SPRITES: array[0..T68_FRAMES - 1] of Integer =
    (492, 493, 494, 495, 496, 497, 498, 499);
  T68_INSET_ADDR = $0046C498;
  { One entry per frame, written to BOTH insets. The catchable window is the
    animation itself - see the T67_/T68_ note above. }
  T68_INSET: array[0..T68_FRAMES - 1] of Integer =
    (70, 55, 55, 40, 40, 50, 90, 90);
  T68_RISE = -$10;
  T68_GRAVITY = 2;
  T68_TERMINAL = $200;
  T68_RISING_STATE = 3;
  T68_CAUGHT_STATE = 4;     { nothing in this handler ever sets it }

  { Type 69 sets its event flag unconditionally after being destroyed. Type 70
    is destroyed by any damage; variant 1 intentionally uses low sprite ids. }
  T69_FRAMES = 4;
  T69_TABLE_ADDR = $0046C4B8;
  T69_SPRITES: array[0..T69_FRAMES - 1] of Integer = (430, 431, 432, 433);
  T69_FRICTION = 4;
  T69_FLOOR_PROBE = $400;   { one tile down; it acts when there is NO floor }
  T69_PRIZE_TYPE = $44;     { 68, spawned straight into its falling state }
  T69_PRIZE_STATE = 4;
  T69_PRIZE_HP = 1;

  T70_FRAMES = 4;  T70_TICKS = 8;
  T70_WALKER = 1;           { variant 1 walks; variant 0 stands still }
  T70_V0_TABLE_ADDR = $0046C4C8;
  T70_V0_SPRITES: array[0..4] of Integer = (434, 435, 436, 435, 437);
  T70_V1_TABLE_ADDR = $0046C4DC;
  T70_V1_SPRITES: array[0..4] of Integer = (0, 1, 2, 1, 1);
  T70_WOUND_FRAME = 4;
  T70_FULL_HP = 100;        { any value but this one counts as wounded }
  T70_WALK_SPEED = $20;
  T70_LEDGE_PROBE = $400;
  T70_DYING_FOR = $78;      { 120 frames of the wound frame, then hp := 0 }

  { Types 71 and 72. Type 71's walk timer only advances while it is ON SCREEN,
    so one that has wandered off the edge walks for ever and never presents
    its vulnerable phase. Its rest table is keyed on COMPLETED curl loops, so
    the harder the game the shorter the window in which it can be hurt.

    Type 72 variant 1 never writes EF_VEL_X or EF_VEL_Y, yet hands the trail
    its EF_VEL_* anyway - whatever it was spawned with, not where it is
    actually going - so the trail does not follow it. Written as found. }
  T71_ROW = 6;
  T71_WALK_FRAMES = 2;  T71_WALK_TICKS = 8;
  T71_CURL_FIRST = 2;   T71_CURL_LAST = 5;  T71_CURL_TICKS = 8;
  T71_TABLE_ADDR = $0046C4F0;
  T71_SPRITES: array[0..1, 0..T71_ROW - 1] of Integer =
    ((443, 444, 445, 446, 447, 446),      { going left  }
     (448, 449, 445, 446, 447, 446));     { going right - four are shared }
  T71_WALK_ADDR = $0046C520;
  T71_REST_ADDR = $0046C52C;
  T71_WALK: array[0..2] of Integer = (180, 180, 180);   { flat }
  T71_REST: array[0..2] of Integer = (2, 1, 0);         { loops, not frames }
  T71_SPEED_SHIFT = 5;
  T71_EASY_HP_PENALTY = -2;
  T71_LEDGE_PROBE = $400;
  T71_OFFSCREEN_MARGIN = 2;
  T71_VULN_WALKING = 7;
  T71_VULN_RESTING = 1;
  T71_STUN = 10;
  T71_SND_CURL = $1C;

  T72_V0_FRAMES = 8;  T72_V0_TICKS = 2;
  T72_V0_TABLE_ADDR = $0046C538;
  T72_V0_SPRITES: array[0..T72_V0_FRAMES - 1] of Integer =
    (472, 473, 474, 475, 476, 477, 478, 479);
  T72_V1_DIRS = 16;         { sixteen sprites for sixty-four headings }
  T72_V1_TABLE_ADDR = $0046C594;
  T72_V1_SPRITES: array[0..T72_V1_DIRS - 1] of Integer =
    (450, 451, 452, 453, 454, 455, 456, 457,
     458, 459, 460, 461, 462, 463, 464, 465);
  T72_V2_FRAMES = 4;  T72_V2_TICKS = 4;
  T72_V2_TABLE_ADDR = $0046C5EC;
  T72_V2_SPRITES: array[0..T72_V2_FRAMES - 1] of Integer = (469, 468, 467, 466);
  T72_SPEED_ADDR = $0046C5D4;
  T72_TRAIL_ADDR = $0046C5E0;
  T72_SPEED: array[0..2] of Integer = (2, 3, 4);
  T72_TRAIL: array[0..2] of Integer = (6, 4, 2);   { harder trails thicker }
  T72_DIR_SHIFT = 2;
  T72_GRAVITY = 4;
  T72_TERMINAL = $200;
  T72_FALLER_CLASS = 6;
  T72_FALLER_VULN = 1;
  T72_FLYER_DEPTH = 3;
  T72_FLYER_LIFE = $168;    { 360 frames }
  T72_TRAIL_DEPTH = 4;
  T72_TRAIL_BLINK = 2;
  T72_SELF_TYPE = $48;      { 72 - the flyer trails copies of itself }
  T72_TRAIL_VARIANT = 2;

  { Types 73 and 74. Type 73 hands THREE state transitions to three different
    children - state 3 to a type 75, state 5 to a type 74, state 8 to a type
    35 - and nothing in its own handler leaves any of them. Read alone it
    looks like it deadlocks three times over.

    `if EF_HP = 0 then frame := 4` sits BEFORE Entity_UpdateDying, so the dead
    pose shows on the frame the death sequence starts rather than one later.

    Type 74's fan duplicates type 56's attack values in separate tables, as do
    the HP tables for types 52 and 54. }
  T73_FRAMES = 4;  T73_TICKS = 8;
  T73_TABLE_ADDR = $0046C5FC;
  T73_SPRITES: array[0..4] of Integer = (500, 501, 502, 501, 503);
  T73_DEAD_FRAME = 4;
  T73_WAIT_ADDR   = $0046C610;
  T73_CHARGE_ADDR = $0046C61C;
  T73_WAIT:   array[0..2] of Integer = (20, 15, 10);
  T73_CHARGE: array[0..2] of Integer = (60, 30, 10);
  T73_HP_PACE_DIV = 4;      { hp div 4, times the wait, plus ... }
  T73_HP_PACE_ADD = $14;    { ... twenty }
  T73_ENTRY_SHIFT = -$100;  { 8 px left and 8 px up, once }
  T73_CHILD_LEFT = $400;    { every child appears 32 px to the left }
  T73_CHILD_DOWN_A = $C0;   { 6 px for the type 75 and the type 35 ... }
  T73_CHILD_DOWN_B = $100;  { ... and 8 px for the type 74 }
  T73_CHILD_ONE = $4B;      { 75 - moves it out of state 3 }
  T73_CHILD_TWO = $4A;      { 74 - moves it out of state 5 }
  T73_CHILD_THREE = $23;    { 35 - the marker type 31 uses too }
  T73_RECOVER = $1E;
  T73_SND_CHARGE = $32;

  T74_V0_FRAMES = 5;  T74_V0_TICKS = 4;
  T74_V0_TABLE_ADDR = $0046C628;
  T74_V0_SPRITES: array[0..T74_V0_FRAMES - 1] of Integer =
    (512, 513, 514, 515, 516);
  T74_V1_FRAMES = 4;  T74_V1_TICKS = 2;
  T74_V1_TABLE_ADDR = $0046C63C;
  T74_V1_SPRITES: array[0..T74_V1_FRAMES - 1] of Integer = (515, 516, 515, 516);
  T74_SKEW_ADDR  = $0046C64C;
  T74_COUNT_ADDR = $0046C658;
  T74_SPEED_ADDR = $0046C664;
  { The same three sets of numbers as T56_SKEW, T56_COUNT and T56_SPEED. }
  T74_SKEW:  array[0..2] of Integer = (0, -4, -8);
  T74_COUNT: array[0..2] of Integer = (0, 2, 4);
  T74_SPEED: array[0..2] of Integer = (2, 2, 3);
  T74_FAN_STEP = 4;
  T74_FAN_WRAP = $3C;
  T74_SELF_TYPE = $4A;      { 74 - the charge-up throws copies of itself }
  T74_SHOT_VARIANT = 1;
  T74_OWNER_STATE = 6;      { what it writes into its parent before it goes }

  { Types 75 and 76. Type 75 dies with its parent - after the dying check it
    reads the OWNER's EF_HP and destroys itself if that is zero. No other
    child does this; types 35, 39 and 74 outlive a dead parent.

    Type 76's lap sound fires when the new heading equals 63, not when it
    wraps to 0. Type 66's satellite plays the same sound on the wrap itself:
    the two sound triggers are one direction step apart. }
  T75_FRAMES = 8;  T75_TICKS = 4;
  T75_TABLE_ADDR = $0046C670;
  T75_SPRITES: array[0..T75_FRAMES - 1] of Integer =
    (504, 505, 506, 507, 508, 509, 510, 511);
  T75_OPENING = 0;          { reads the table forwards ... }
  T75_CLOSING = 1;          { ... and this one backwards }
  T75_OWNER_AFTER_OPEN = 4;
  T75_OWNER_AFTER_CLOSE = 1;
  T75_SND_OPEN = $18;

  T76_FRAMES = 2;  T76_TICKS = 2;
  T76_TABLE_ADDR = $0046C690;
  T76_SPRITES: array[0..T76_FRAMES - 1] of Integer = (422, 423);
  T76_PERIOD_ADDR = $0046C698;
  T76_SPEED_ADDR  = $0046C6A4;
  T76_PERIOD: array[0..2] of Integer = (4, 2, 2);   { frames between steps }
  T76_SPEED:  array[0..2] of Integer = (1, 2, 2);
  T76_NUDGE = $200;         { 16 px right, once }
  T76_LAP_AT = $3F;         { the step BEFORE the wrap, not the wrap }
  T76_SND_LAP = $2E;

  { Type 77, the final boss - the only handler that runs from a SCRIPT rather
    than a hand-written state chain: two 6x6 tables, durations and actions,
    indexed by [phase][step].

    Each phase's sprite table is exactly as wide as the highest frame that
    phase's script can reach. }
  T77_PHASES = 6;
  T77_STEPS = 6;

  { Phases 0 and 1 share this value. }
  T77_P01_TABLE_ADDR = $0046C6B0;
  T77_P01_SPRITES: array[0..1, 0..9] of Integer =
    ((584, 585, 500, 501, 502, 503, 535, 534, 535, 536),
     (586, 587, 504, 505, 506, 507, 538, 537, 538, 539));
  T77_P2_TABLE_ADDR = $0046C700;
  T77_P2_SPRITES: array[0..1, 0..13] of Integer =
    ((588, 589, 508, 509, 510, 511, 541, 540, 541, 542, 566, 567, 568, 592),
     (590, 591, 512, 513, 514, 515, 544, 543, 544, 545, 569, 570, 571, 593));
  T77_P3_TABLE_ADDR = $0046C770;
  T77_P3_SPRITES: array[0..1, 0..12] of Integer =
    ((594, 595, 516, 517, 518, 519, 547, 546, 547, 548, 572, 573, 574),
     (596, 597, 520, 521, 522, 523, 550, 549, 550, 551, 575, 576, 577));
  T77_P4_TABLE_ADDR = $0046C7D8;
  T77_P4_SPRITES: array[0..1, 0..5] of Integer =
    ((552, 553, 524, 525, 526, 527),
     (554, 555, 528, 529, 530, 531));
  T77_P5_TABLE_ADDR = $0046C808;
  T77_P5_SPRITES: array[0..1, 0..7] of Integer =
    ((578, 579, 558, 559, 560, 561, 556, 557),
     (580, 581, 562, 563, 564, 565, 556, 557));
  { phase 6 is the dead pose, and both directions are the same sprite }
  T77_P6_TABLE_ADDR = $0046C848;
  T77_P6_SPRITES: array[0..1] of Integer = (598, 598);

  T77_HP_ADDR = $0046C850;
  T77_HP: array[0..2, 0..T77_PHASES - 1] of Integer =
    ((968, 936, 904, 840, 808, 776),
     (968, 936, 904, 840, 808, 776),    { the same fight as easy }
     (984, 952, 920, 888, 856, 824));

  T77_STEP_ADDR   = $0046C8B4;
  T77_ACTION_ADDR = $0046C944;
  T77_DIVISOR_ADDR = $0046C9D4;
  T77_STEP: array[0..T77_PHASES - 1, 0..T77_STEPS - 1] of Integer =
    ((180, 0, 0, 180, 0, 0),
     (180, 0, 60, 180, 0, 60),
     (120, 0, 30, 120, 0, 60),
     (30, 0, 0, 0, 0, 30),
     (30, 0, 30, 0, 30, 0),
     (30, 0, 30, 30, 0, 30));
  T77_ACTION: array[0..T77_PHASES - 1, 0..T77_STEPS - 1] of Integer =
    ((2, 3, 0, 2, 3, 0),
     (2, 3, 4, 2, 3, 4),
     (2, 6, 5, 2, 3, 4),
     (4, 2, 3, 2, 3, 5),
     (2, 7, 2, 7, 2, 7),
     (2, 3, 8, 2, 3, 8));
  T77_DIVISOR: array[0..2] of Integer = (1, 2, 4);   { harder runs it faster }

  { T77_ACTION's values - what the step does when its duration runs out. The
    frame each one starts on is EF_FLAG1C in the arm below. }
  T77_ACT_WAIT      = 0;   { wait again }
  T77_ACT_FACE      = 2;   { turn to face the player }
  T77_ACT_DASH      = 3;   { dash, leaving a trail }
  T77_ACT_SLAM      = 4;   { the ground slam }
  T77_ACT_SHOT      = 5;   { the projectile }
  T77_ACT_RECOIL    = 6;   { like the dash, faster and backwards }
  T77_ACT_DASH_BACK = 7;   { the dash, entered facing the other way }
  T77_ACT_POSE      = 8;   { a held pose that spawns a variant-5 part }

  T77_SLAM_ADDR     = $0046C898;
  T77_SLAM_DIV_ADDR = $0046C9E0;
  T77_SLAM: array[0..3] of Integer = (4, 90, 2, 60);   { frames 6..9 }
  T77_SLAM_DIV: array[0..2] of Integer = (1, 1, 2);
  T77_SHOT_ADDR     = $0046C8A8;
  T77_SHOT_DIV_ADDR = $0046C9EC;
  T77_SHOT: array[0..2] of Integer = (90, 4, 60);      { frames 10..12 }
  T77_SHOT_DIV: array[0..2] of Integer = (1, 1, 2);

  T77_BURST_ADDR   = $0046C588;
  T77_BURST_VX_ADDR = $0046C558;
  T77_BURST_VY_ADDR = $0046C570;
  T77_BURST: array[0..2] of Integer = (1, 3, 5);       { plus one }
  T77_BURST_VX: array[0..5] of Integer = (2, -2, 5, -5, 10, -10);
  T77_BURST_VY: array[0..5] of Integer = (-24, -24, -20, -20, -14, -14);
  T77_BURST_SHIFT = 3;
  T77_BURST_TYPE = $48;     { 72 variant 0, the faller }

  T77_LOB_SPEED_ADDR = $0046CADC;
  T77_LOB_SPEED: array[0..2] of Integer = (1, 2, 3);

  T77_ENTRY_VX = -$10;
  T77_PART_A = $4E;         { 78 - spawned once, at the start }
  T77_PART_B = $4F;         { 79 - spawned once, and again for every effect }
  T77_TURN_SPEED = $60;
  T77_TURN_HOLD = $3C;
  T77_DASH_FRICTION = 2;
  T77_RECOIL_FRICTION = 4;
  T77_IDLE_TICKS = 8;
  T77_HELD_TICKS = 4;
  T77_HELD_FIRST = 6;
  T77_HELD_LAST = 7;
  T77_PUFF_LIFT = $20;
  T77_SHAKE_FRAMES = $3C;
  T77_SND_ROAR = $33;
  T77_SND_SLAM = $30;
  T77_SND_LOB = $2E;

  { Types 78, 79 and 80, the boss's furniture. Three things kept as written:

      78  clears EF_TOUCH_KIND for the whole of the lob, so the wind-up is the
          one window in which this half of the boss is safe to stand beside.
      79  variant 3 dies when its timer reaches 1, not 0 - one frame early,
          and deliberate: Entity_UpdateAll decrements it after the handler.
      80  both variants share ONE counter. EF_BLOCK_B is incremented at the
          top for both and AGAIN inside variant 1, so variant 1 runs at twice
          the rate off a field that is counted twice. }
  T78_SLAM_X_ADDR = $0046CA28;
  T78_SLAM_Y_ADDR = $0046CA48;
  T78_SLAM_X: array[0..1, 0..3] of Integer =
    ((0, 68, -16, -60), (0, -68, 16, 60));
  T78_SLAM_Y: array[0..3] of Integer = (-54, 0, -54, 0);
  T78_LOB_X_ADDR = $0046CA70;
  T78_LOB_Y_ADDR = $0046CA88;
  T78_LOB_X: array[0..1, 0..2] of Integer = ((60, -4, 8), (-60, 4, -8));
  T78_LOB_Y: array[0..2] of Integer = (-22, 0, -72);
  T78_IDLE_TABLE_ADDR = $0046C9F8;
  T78_IDLE_SPRITES: array[0..1] of Integer = (600, 601);
  T78_SLAM_TABLE_ADDR = $0046CA08;
  T78_SLAM_SPRITES: array[0..1, 0..3] of Integer =
    ((607, 602, 606, 603), (606, 604, 607, 605));
  T78_LOB_TABLE_ADDR = $0046CA58;
  T78_LOB_SPRITES: array[0..1, 0..2] of Integer =
    ((608, 610, 607), (609, 611, 606));
  T78_IDLE_X_ADDR = $0046CA00;
  T78_IDLE_X: array[0..1] of Integer = (-7, 7);
  T78_OFFSET_SCALE = $20;
  T78_IDLE_HIGH = -$680;    { on the boss's frames 0, 3 and 5 ... }
  T78_IDLE_LOW  = -$6A0;    { ... and on every other frame }
  T78_LEAVES_AT_PHASE = 5;

  T79_V0_TABLE_ADDR = $0046CA94;
  T79_V0_SPRITES: array[0..1] of Integer = (532, 533);
  T79_V1_TABLE_ADDR = $0046CAA4;
  T79_V1_SPRITES: array[0..1] of Integer = (612, 613);
  T79_V2_TABLE_ADDR = $0046CAB8;
  T79_V2_SPRITES: array[0..1] of Integer = (613, 612);   { v1's, reversed }
  T79_V3_TABLE_ADDR = $0046CACC;
  T79_V3_SPRITES: array[0..1, 0..1] of Integer = ((614, 615), (616, 617));
  T79_V4_TABLE_ADDR = $0046CAE8;
  T79_V4_SPRITES: array[0..3] of Integer = (291, 292, 293, 294);
  T79_V5_TABLE_ADDR = $0046CAF8;
  T79_V5_SPRITES: array[0..5] of Integer = (471, 470, 469, 468, 467, 466);
  T79_V0_X_ADDR = $0046CA9C;
  T79_V1_X_ADDR = $0046CAAC;
  T79_V1_Y_ADDR = $0046CAB4;
  T79_V2_X_ADDR = $0046CAC0;
  T79_V2_Y_ADDR = $0046CAC8;
  T79_V0_X: array[0..1] of Integer = (1, -1);
  T79_V1_X: array[0..1] of Integer = (-80, 80);
  T79_V1_Y: array[0..0] of Integer = (-48);
  T79_V2_X: array[0..1] of Integer = (80, -80);
  T79_V2_Y: array[0..0] of Integer = (-48);
  T79_V0_HIGH = -$160;      { on the boss's frames 1, 2 and 4 }
  T79_V0_LOW  = -$180;
  T79_V0_LEAVES_AT_PHASE = 1;
  T79_V1_LIFE = 10;
  T79_V2_LIFE = 2;
  T79_LOB_SND_EVERY = $1E;
  T79_LOB_FUSE = $F;        { armed on a wall, or on running out of time }
  T79_LOB_LIFE = $78;
  T79_V4_FRAMES = 4;
  T79_SUMMON_WAIT = $1E;
  T79_SUMMON_LAST = 5;
  T79_SUMMONS = 4;          { three flyers, and the fourth pass hands back }
  T79_FLYER_TYPE = $48;     { 72 ... }
  T79_FLYER_VARIANT = 1;    { ... variant 1, the one that picks its sprite
                              by heading }
  T79_SND_LOB = $2E;
  T79_SND_SUMMON = $34;

  T80_V0_FRAMES = 3;  T80_V0_TICKS = 8;
  T80_V0_TABLE_ADDR = $0046CB10;
  T80_V0_SPRITES: array[0..T80_V0_FRAMES - 1] of Integer = (582, 583, 599);
  T80_V1_FRAMES = 4;  T80_V1_TICKS = 2;
  T80_V1_TABLE_ADDR = $0046CB1C;
  T80_V1_SPRITES: array[0..T80_V1_FRAMES - 1] of Integer = (64, 65, 66, 65);
  T80_V1_BLINK = 2;

  { Types 8 and 26 are spawned effects that play a short animation and destroy
    themselves.

    Type 26's VARIANT is the whole difference between its two sprites: 0 for
    an ordinary stone, 1 when the stone completed a target and paid a life.

    Their frame indexes cannot overflow because the terminating frame destroys
    each entity. }
  TYPE8_FRAMES      = 4;
  TYPE8_TICKS       = 4;    { advance when the count EXCEEDS it, so every 5 }
  TYPE8_TABLE_ADDR  = $0046BCCC;
  TYPE8_SPRITES: array[0..TYPE8_FRAMES - 1] of Integer = (50, 51, 52, 53);

  TYPE26_LIFT       = $10;  { 16 sub-pixels a frame, straight up }
  TYPE26_LIFETIME   = $1E;  { destroyed when the count EXCEEDS 30 }
  TYPE26_TABLE_ADDR = $0046BE14;
  { All four entries are addressable even though shipped data uses variants 0
    and 1. }
  TYPE26_VARIANTS   = 4;
  TYPE26_SPRITES: array[0..TYPE26_VARIANTS - 1] of Integer =
    (83, 99, 102, 103);

  { Types 16 and 22 each select one fixed sprite. }
  SIGN_SPRITE       = 54;
  SIGN_SPRITE_ADDR  = $0046BE74;
  TYPE22_SPRITE     = 60;
  TYPE22_SPRITE_ADDR = $0046BE84;

  { Type 33 throws six sparks on its first update.
    type-6 sparks, each taking one random heading of 64 and a velocity from
    BOTH direction tables at that index, which is what makes the burst radial
    rather than axis-aligned. The two speed multipliers are drawn SEPARATELY,
    so a spark's X and Y speeds are independent and the scatter is an ellipse
    of random eccentricity. }
  BOOM_FRAMES     = 6;
  BOOM_TICKS      = 6;    { advance when the count EXCEEDS it, so every 7 }
  BOOM_TABLE_ADDR = $0046BE3C;
  BOOM_TABLE_PTR  = $0046CE30;
  BOOM_SPRITES: array[0..BOOM_FRAMES - 1] of Integer = (93, 94, 95, 96, 97, 98);
  BOOM_SPARK_TYPE = 6;
  BOOM_SPARKS     = 6;
  BOOM_SPEED_MAX  = 3;    { RandomBelow(3) + 1, so 1..3, per axis }

  { Type 32 is an invisible spawner that reads its
    configuration out of block A and keeps its state in block B:

      A[1] $09  frames between spawns    B[0] $12  countdown to the next
      A[2] $0A  how many in all          B[1] $13  how many so far
      A[3] $0B  scatter radius           B[2] $14  countdown to the next sound
      A[4] $0C  frames between sounds

    The scatter is Random(r * 16) - r * 8 PIXELS on each axis - quarter tiles,
    not tiles. Entity_UpdateDying seeds it two ways, which is how one emitter
    type gives two different deaths.

    The exhaustion test is `A[2] < B[1]` AFTER the increment, so an emitter
    configured for N spawns N + 1 times. }
  EMIT_EVERY       = $09;   { A[1] }
  EMIT_TOTAL       = $0A;   { A[2] }
  EMIT_RADIUS      = $0B;   { A[3] }
  EMIT_SOUND_EVERY = $0C;   { A[4] }
  EMIT_NEXT        = $12;   { B[0] }
  EMIT_COUNT       = $13;   { B[1] }
  EMIT_SOUND_NEXT  = $14;   { B[2] }
  EMIT_SPAWN_TYPE  = $21;   { 33, the explosion }
  EMIT_RADIUS_SHIFT = 4;    { Random(r shl 4), centred by r * 8 }

  { Projectile damage switches on the target's
    EF_VULN_KIND, with the projectile's own EF_STATE as its POWER. Most arms
    are immunity, and several are conditional on that power, which is what
    makes them armour rather than invulnerability:

        2, $5C   immune outright
        $5A      immune to power below 1
        $5B      immune to power below 2
        $5D      immune UNLESS the power is exactly 3
        4        immune unless the power is exactly 4

    A power-3 shot is skipped entirely unless the kind is $5D, so that power
    exists to open exactly one kind of door.

    Kind 7 REFLECTS, and is the only place in the game seen writing all four
    hitbox percentage columns at runtime. Powers 2 and 3 PIERCE - not
    destroyed, and able to hit again - and power 4 is destroyed WITH loot.
    Only the special arms return early, so an ordinary hit carries on scanning
    and several shots can land in one pass. }
  VULN_IMMUNE        = 2;
  VULN_ONLY_POWER4   = 4;
  VULN_SHOVE         = 5;
  VULN_SPIN          = 6;
  VULN_REFLECT       = 7;
  VULN_ARMOUR_1      = $5A;   { immune below power 1 }
  VULN_ARMOUR_2      = $5B;   { immune below power 2 }
  VULN_IMMUNE_ALT    = $5C;
  VULN_ONLY_POWER3   = $5D;

  HIT_SPARK_TYPE = 10;
  REFLECT_TYPE   = 2;
  REFLECT_LIFE   = 600;
  REFLECT_BOX_STRONG = $1E;   { the four percentage columns, power 2 }
  REFLECT_BOX_WEAK   = $3C;
  SPIN_MARK      = $EC;       { 236, into int $15 }
  SPIN_TURN      = $18;       { 24 of 64 }
  SHOVE_SPEED_SHIFT = 6;      { direction shl 6 }
  SHOVE_FRAMES   = 4;         { the frame wraps 0..3 }
  HIT_INVULN     = 8;
  PIERCING_POWER_A = 2;       { these are not consumed by the hit }
  PIERCING_POWER_B = 3;
  LOOT_POWER       = 4;       { this one is destroyed WITH loot }

  { Hit sounds selected by the target's type data. }
  HIT_SOUND_COUNT = 4;
  HIT_SOUND_ADDR  = $00468E34;
  HIT_SOUND_PTR   = $0046CC48;
  HIT_SOUNDS: array[0..HIT_SOUND_COUNT - 1] of Integer =
    (SND_KIN01, SND_SHOT01, SND_PI02, SND_MOVE01);

  { --- Entity_UpdateDying ------------------------------------------------- }
  DEATH_CLASS_SMALL  = 1;
  DEATH_CLASS_BIG    = 2;
  DEATH_CLASS_DEBRIS = 6;
  EMITTER_TYPE       = $20;   { type 32, the invisible spawner }
  SND_BOM03          = $22;   { 34 }

{ Death handling is called before normal behavior by most entity handlers.
  every per-type handler. Returns True when it has taken over, and the caller
  must then skip its normal update.

  It engages only for EF_CLASS 1, 2, and 6.

  Classes 1 and 2 both spawn a type-32
  emitter - the invisible spawner whose configuration lives in its block A -
  and seed four of its block-A slots with different numbers, which is how one
  emitter type produces two different death effects.

      class 1   death timer  30, timer  60, emitter A[1..4] = 8, 2, 1, 2
      class 2   death timer 180, timer 240, emitter A[1..4] = 4, 32, 4, 1
      class 6   death timer   0, and Entity_SpawnDebris(e, 1) instead

  Class 6 zeroing its death timer means it is destroyed on the same frame it
  starts dying; 1 and 2 linger for their timer first. Class 2 also plays sound
  34 (bom03) as it goes. }
function EntityUpdateDying(var E: TEntity; AGameState: Integer;
                           World: TEntityWorld): Boolean;

{ Collects a Mana Stone. The counter climbs by the entity's variant, and
  when it reaches MANA_TARGETS[TargetIndex] the player gains a life of maximum
  AND is refilled - which is what tk001.dat describes in words. }
procedure EntityTouchPickup(var E: TEntity; var P: TPlayerState;
                            World: TEntityWorld);

{ Applies a full heal. }
procedure EntityTouchHeal(var E: TEntity; var P: TPlayerState;
                          World: TEntityWorld);

{ Collects a life pickup. Its variant comes from EF_FLAG1C, which is the
  very field Entity_MaybeDropItem sets from its rarity roll - so a dropped
  item's rare flag is what decides +1 life against a full refill. }
procedure EntityTouchLife(var E: TEntity; var P: TPlayerState;
                          World: TEntityWorld);

{ Applies a hit to the player. }
procedure PlayerTakeDamage(var Player: TEntity; var P: TPlayerState;
                           Damage: Integer; World: TEntityWorld);

{ Dispatches player contact behavior. }
procedure PlayerTouch(var E, Player: TEntity; var P: TPlayerState;
                      var Inp: TInputState; World: TEntityWorld);

{ Applies projectile hits from actor slots to this entity. }
procedure TakeProjectileHits(var E: TEntity; World: TEntityWorld);

{ Per-frame entity-pool update. }

const
  { Reference handler-address index used by coverage and differential tests.
    Zero indicates a type without a dispatch arm. }
  HANDLER_ADDR: array[0..ENTITY_TYPE_COUNT - 1] of Cardinal = (
    $00000000, $004585A8, $00459A0C, $00459EB4,   { 0..3 }
    $00459F1C, $00459F6C, $0045A020, $0045A08C,   { 4..7 }
    $0045A0E4, $0045A120, $0045A184, $0045A1C0,   { 8..11 }
    $0045A20C, $0045A24C, $0045A3E0, $0045A95C,   { 12..15 }
    $0045A944, $0045A9D4, $00000000, $0045A9D0,   { 16..19 }
    $00000000, $0045AA10, $0045AA60, $0045AA78,   { 20..23 }
    $0045A43C, $0045A4F0, $0045A50C, $0045A540,   { 24..27 }
    $0045A580, $0045AB64, $0045ABD8, $0045AC94,   { 28..31 }
    $0045A5D4, $0045A698, $0045AF2C, $0045AFA8,   { 32..35 }
    $0045A7BC, $0045A848, $0045B0CC, $0045B260,   { 36..39 }
    $0045B3EC, $0045B62C, $0045B7C4, $0045BBD8,   { 40..43 }
    $0045BC00, $0045BCC4, $0045BD9C, $0045BF58,   { 44..47 }
    $0045C0F4, $0045C250, $0045C430, $0045C608,   { 48..51 }
    $0045C678, $0045CA28, $0045CAD8, $0045CC98,   { 52..55 }
    $0045CE78, $0045D00C, $0045D598, $0045D670,   { 56..59 }
    $0045D7D8, $0045DA28, $0045DC84, $0045DDF4,   { 60..63 }
    $0045E030, $0045E25C, $0045E4EC, $0045E714,   { 64..67 }
    $0045EA40, $0045EB1C, $0045EC4C, $0045ED88,   { 68..71 }
    $0045EFC8, $0045F218, $0045F498, $0045F668,   { 72..75 }
    $0045F744, $0045F85C, $0046023C, $004603B4,   { 76..79 }
    $004607E8    { 80..80 });

  HANDLER_NONE = 0;

  { Reference image mapping used to validate the handler jump table. }
  CODE_VA_BIAS          = $00400C00;   { VA = file offset + this, CODE section }
  HANDLER_JUMP_TABLE    = $00460924;
  HANDLER_NO_ARM_TARGET = $00460DE1;

  { Type 68 receives an extra touch pass in state 3. Table-spawned instances
    have touch kind 0, while type 57's hatchling uses touch kind 1 and can
    damage the player. Type 69 instead spawns a harmless state-4 instance. }
  TYPE_TOUCH_IN_STATE_3 = $44;   { 68 }

type
  { Swappable callbacks let entity self-tests observe the interaction passes
    without changing gameplay behavior. }
  TTouchProc = procedure(var E, Player: TEntity; var P: TPlayerState;
                         var Inp: TInputState; World: TEntityWorld);

  TEntityCallback = procedure(var E: TEntity; World: TEntityWorld);

var
  EntityPlayerTouch:        TTouchProc = nil;
  EntityTakeProjectileHits: TEntityCallback = nil;

{ Walks updateable slots 0..$FF rather than the entire pool,
  and for each live one: carries it along with the scroll unless it is
  screen-space, runs its per-type handler, pushes its state onto its sprite,
  ticks its two timers, rebuilds its collision boxes from the sprite size, and
  finally offers it to the touch and projectile passes before culling it if it
  has left the screen.

  AGameState is var because it is READ FRESH at four points and a handler can
  change it mid-loop. That is not defensive: the last of those four reads exists
  precisely so that a touch which starts an event script abandons the rest of
  the frame's entities. }
{ Runs one type handler; exposed for isolated handler tests. }
procedure EntityRunHandler(var E: TEntity; var P: TPlayerState;
                           var L: TLayerInfo; var Inp: TInputState;
                           World: TEntityWorld; AGameState: Integer);

procedure EntityUpdateAll(Pool: TEntityPool; World: TEntityWorld;
                          Sprites: TSpriteSink;
                          var P: TPlayerState; var L: TLayerInfo;
                          var Inp: TInputState; var AGameState: Integer);

{ Computes Half * Percent / 100 using integer arithmetic that reproduces the
  three required rounding stages consistently across architectures:

      d := RN64(Percent / 100)     the FDIV, one rounding
      m := RN64(Half * d)          the FMULP, a second
      result := RNint(m)           the store, round half to even

  Away from a tie the exact value sits at least 1/100 from a .5 boundary while
  the FPU's relative error is about 1e-19, so neither rounding can move the
  answer and plain integer division gives it. Every case where x87 rounding
  disagrees with exact arithmetic is a tie - Half * Percent = 50 (mod 100) - and
  the whole tail of this function is about which way the hardware breaks it.

  Checked against an independent exact-rational simulation of the x87 sequence
  over all 103,525 cases: no disagreement. --selftest-entities re-checks the
  part of that which can be stated without the simulation. }
function ScaleByPercent(Half, Percent: Integer): Integer;

{ One int of the sprite DATA region - the four unchecked handlers read through
  this so an overrun lands in the same contiguous region. }
function SpriteDatum(Index: Integer): Integer;


implementation

uses
  EntityBosses, EntityEffects, EntityMonsters, EntityPickups, EntityProjectiles, EntityTerrain;

function EntityUpdateDying(var E: TEntity; AGameState: Integer;
                           World: TEntityWorld): Boolean;
var
  SpawnedSlot: Integer;
begin
  { Outside play the guard reports True without doing anything, so every
    handler stops dead during an event script or the game-over screen. }
  if AGameState <> GS_PLAY then
    Exit(True);

  Result := False;
  if E.Raw[EF_HP] >= 1 then
    Exit;
  if not (E.Raw[EF_CLASS] in [DEATH_CLASS_SMALL, DEATH_CLASS_BIG,
                              DEATH_CLASS_DEBRIS]) then
    Exit;

  if E.Raw[EF_DYING] = 0 then
  begin
    E.Raw[EF_DYING] := 1;
    case E.Raw[EF_CLASS] of
      DEATH_CLASS_SMALL:
        begin
          E.Raw[EF_DEATH_TIMER] := 30;
          E.Raw[EF_TIMER] := 60;
          SpawnedSlot := World.Spawn(2, EMITTER_TYPE,
                              E.Raw[EF_POS_X] - POSITION_BIAS,
                              E.Raw[EF_POS_Y] - POSITION_BIAS - $20);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 1, 8);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 2, 2);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 3, 1);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 4, 2);
        end;
      DEATH_CLASS_BIG:
        begin
          E.Raw[EF_DEATH_TIMER] := 180;
          E.Raw[EF_TIMER] := 240;
          SpawnedSlot := World.Spawn(2, EMITTER_TYPE,
                              E.Raw[EF_POS_X] - POSITION_BIAS,
                              E.Raw[EF_POS_Y] - POSITION_BIAS - $20);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 1, 4);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 2, $20);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 3, 4);
          World.SetSpawnField(SpawnedSlot, EF_BLOCK_A + 4, 1);
        end;
      DEATH_CLASS_DEBRIS:
        begin
          E.Raw[EF_DEATH_TIMER] := 0;
          World.SpawnDebris(E, 1);
        end;
    end;
  end;

  if E.Raw[EF_DEATH_TIMER] = 0 then
  begin
    if E.Raw[EF_CLASS] = DEATH_CLASS_BIG then
      World.PlaySound(SND_BOM03);
    World.DestroyEntity(E, True);
  end;

  Result := True;
end;

{ Both handlers set the progress flag their event names, spawn the same
  effect, and destroy themselves; only the middle differs. }
function PickupCommon(var E: TEntity; World: TEntityWorld): Integer;
var
  Flag: Integer;
begin
  Flag := World.EventProgressIndex(E.Raw[EF_EVENT_ID]);
  if Flag >= 0 then
    World.SetProgress(Flag);
  Result := World.Spawn(EKIND_MINOR, PICKUP_EFFECT_TYPE,
                        E.Raw[EF_POS_X] - POSITION_BIAS,
                        E.Raw[EF_POS_Y] - POSITION_BIAS);
end;

procedure EntityTouchPickup(var E: TEntity; var P: TPlayerState;
                            World: TEntityWorld);
var
  SpawnedSlot: Integer;
begin
  case E.Raw[EF_VARIANT] of
    0: Inc(P.Counter, MANA_SMALL);
    1: Inc(P.Counter, MANA_LARGE);
  end;

  SpawnedSlot := PickupCommon(E, World);

  { The comparison happens AFTER the counter has already gone up, so a stone
    that takes you exactly to the target counts as reaching it. }
  if P.Counter < ManaTarget(P.TargetIndex) then
  begin
    if E.Raw[EF_VARIANT] = 0 then
      World.PlaySound(SND_GET01)
    else if E.Raw[EF_VARIANT] = 1 then
      World.PlaySound(SND_GET02);
    World.SetSpawnField(SpawnedSlot, EF_VARIANT, PICKUP_FX_NORMAL);
  end
  else
  begin
    Inc(P.TargetIndex);
    Inc(P.MaxLives);
    P.Lives := P.MaxLives;
    World.PlaySound(SND_POWER02);
    World.SetSpawnField(SpawnedSlot, EF_VARIANT, PICKUP_FX_LEVELUP);
  end;

  World.DestroyEntity(E, False);
end;

procedure EntityTouchHeal(var E: TEntity; var P: TPlayerState;
                          World: TEntityWorld);
var
  SpawnedSlot: Integer;
begin
  World.PlaySound(SND_KACHI02);
  P.Lives := P.MaxLives;
  SpawnedSlot := PickupCommon(E, World);
  World.SetSpawnField(SpawnedSlot, EF_VARIANT, PICKUP_FX_HEAL);
  World.DestroyEntity(E, False);
end;

procedure EntityTouchLife(var E: TEntity; var P: TPlayerState;
                          World: TEntityWorld);
var
  SpawnedSlot, Variant: Integer;
begin
  { EF_FLAG1C, not EF_VARIANT - the field a dropped item carries its rarity in. }
  Variant := E.Raw[EF_FLAG1C];
  if Variant = 0 then
    Inc(P.Lives)
  else if Variant = 1 then
    P.Lives := P.MaxLives;
  { The +1 path is not clamped here; HUD drawing normalizes the value. }
  World.PlaySound(SND_GET01);
  SpawnedSlot := PickupCommon(E, World);
  World.SetSpawnField(SpawnedSlot, EF_VARIANT, Variant + 2);
  World.DestroyEntity(E, False);
end;

procedure PlayerTakeDamage(var Player: TEntity; var P: TPlayerState;
                           Damage: Integer; World: TEntityWorld);
var
  DamageLeft, SoulIndex, SpawnedSlot: Integer;
begin
  { Being hit out of a glide or an air dash leaves a puff behind. }
  if (Player.Raw[EF_STATE] = 6) or (Player.Raw[EF_STATE] = 7) then
    World.Spawn(EKIND_MINOR, PLAYER_HIT_FX,
                Player.Raw[EF_POS_X] - POSITION_BIAS,
                Player.Raw[EF_POS_Y] - POSITION_BIAS);

  World.PlaySound(SND_VOICE01);
  Player.Raw[EF_TIMER] := PLAYER_HIT_INVULN;
  Player.Raw[EF_DEATH_TIMER] := PLAYER_HIT_INVULN;
  Player.Raw[EF_STATE] := PLAYER_HIT_STATE;
  Player.Raw[EF_VEL_Y] := PLAYER_HIT_LIFT;
  { Thrown backwards relative to the way it faces. }
  if Player.Raw[EF_FACING] = 0 then
    Player.Raw[EF_VEL_X] := -PLAYER_HIT_PUSH
  else
    Player.Raw[EF_VEL_X] := PLAYER_HIT_PUSH;

  if Damage <= 0 then
    Exit;
  DamageLeft := Damage;
  repeat
    for SoulIndex := 0 to SOULS_PER_LIFE - 1 do
    begin
      { At the HUD icon, in screen space - the life being knocked off. }
      SpawnedSlot := World.Spawn(EKIND_MINOR, EF_DEBRIS_TYPE,
                          (P.Lives * HUD_LIFE_STEP + HUD_LIFE_X0) * 32,
                          HUD_LIFE_Y * 32);
      World.SetSpawnField(SpawnedSlot, EF_FACING,
                          World.RandomBelow(4) + SoulIndex * 8 + 8);
      World.SetSpawnField(SpawnedSlot, EF_VEL_Y,
                          World.RandomBelow($10)
                            + Abs(1 - SoulIndex) * $10 - $20);
    end;
    Dec(P.Lives);
    Dec(DamageLeft);
  until (P.Lives = 0) or (DamageLeft = 0);
end;

procedure PlayerTouch(var E, Player: TEntity; var P: TPlayerState;
                      var Inp: TInputState; World: TEntityWorld);
var
  TouchKind, EventId, Opcode: Integer;
begin
  TouchKind := E.Raw[EF_TOUCH_KIND];
  if (Player.Raw[EF_ALIVE] and $FF) = 0 then
    Exit;
  { Invulnerability blocks everything except kind 3. }
  if (Player.Raw[EF_TIMER] <> 0)
     and (TouchKind <> TOUCH_KIND_THRU_INVULN) then
    Exit;
  if TouchKind = 0 then
    Exit;
  if E.Raw[EF_TIMER] <> 0 then
    Exit;

  if not EntitiesOverlap(Player, E, 1, 1) then
    Exit;

  EventId := E.Raw[EF_EVENT_ID];
  if EventId <> -1 then
  begin
    Opcode := World.EventOpcode(EventId);
    if (Opcode = 0)
    or ((Opcode = 1) and (Player.Raw[EF_VEL_Y] = 0)
        and (Inp.AxisY < 0) and (not Inp.AxisYNegative)) then
      World.BeginEvent(EventId, EVENT_BEGIN_FROM_DESTROY);
  end;

  case TouchKind of
    TOUCH_KIND_HURT:      PlayerTakeDamage(Player, P, 1, World);
    TOUCH_KIND_MANA:      EntityTouchPickup(E, P, World);
    TOUCH_KIND_LIFE:      EntityTouchLife(E, P, World);
    TOUCH_KIND_HEAL:      EntityTouchHeal(E, P, World);
    TOUCH_KIND_STOMP:
      { Only while coming DOWN on it - the stomp. }
      if Player.Raw[EF_VEL_Y] > 0 then
        E.Raw[EF_STATE] := 2;
    TOUCH_KIND_HURT_HARD: PlayerTakeDamage(Player, P, 2, World);
  end;
end;

function HitSound(const E: TEntity): Integer;
var
  SoundIndex: Integer;
begin
  SoundIndex := E.Raw[EF_HIT_SOUND];
  if (SoundIndex < 0) or (SoundIndex >= HIT_SOUND_COUNT) then
    SoundIndex := 0;
  Result := HIT_SOUNDS[SoundIndex];
end;

procedure TakeProjectileHits(var E: TEntity; World: TEntityWorld);
var
  ProjectileSlot, Vulnerability, ProjectilePower, Direction: Integer;
  ReflectedSlot, EventId, BoxPercent: Integer;
  TargetBox, ProjectileBox: TBox;
  Projectile: PEntity;
begin
  Vulnerability := E.Raw[EF_VULN_KIND];
  if (Vulnerability = 0) or (E.Raw[EF_TIMER] <> 0)
     or (World.Pool = nil) then
    Exit;

  TargetBox := EntityBox(E, 1, 1);

  for ProjectileSlot := SLOT_ACTOR_FIRST to SLOT_ACTOR_LAST do
  begin
    Projectile := World.Pool.Entity(ProjectileSlot);
    ProjectilePower := Projectile^.Raw[EF_STATE];

    { A power-3 shot is invisible to everything except kind $5D. }
    if not ((Vulnerability = VULN_ONLY_POWER3)
            or (ProjectilePower <> 3)) then
      Continue;
    if (Projectile^.Raw[EF_ALIVE] and $FF) = 0 then
      Continue;
    if Projectile^.Raw[EF_HP] = 0 then { no damage means not a projectile }
      Continue;
    if (E.Raw[EF_ALIVE] and $FF) = 0 then
      Continue;
    if E.Raw[EF_HP] = 0 then
      Continue;

    ProjectileBox := EntityBox(Projectile^, 1, 1);
    if not RectOverlap(ProjectileBox, TargetBox, 0, 0) then
      Continue;

    World.Spawn(EKIND_MINOR, HIT_SPARK_TYPE,
                Projectile^.Raw[EF_POS_X] - POSITION_BIAS,
                Projectile^.Raw[EF_POS_Y] - POSITION_BIAS);

    EventId := E.Raw[EF_EVENT_ID];
    if (EventId <> -1) and (World.EventOpcode(EventId) = 6) then
      World.BeginEvent(EventId, EVENT_BEGIN_FROM_DESTROY);

    if Vulnerability = VULN_REFLECT then
    begin
      ReflectedSlot := World.Spawn(EKIND_MINOR, REFLECT_TYPE,
        Projectile^.Raw[EF_POS_X] - POSITION_BIAS,
        Projectile^.Raw[EF_POS_Y] - POSITION_BIAS);
      World.SetSpawnField(ReflectedSlot, EF_VEL_X,
        -Projectile^.Raw[EF_VEL_X]);
      World.SetSpawnField(ReflectedSlot, EF_STATE, ProjectilePower);
      World.SetSpawnField(ReflectedSlot, EF_CHILD_B, REFLECT_LIFE);
      World.SetSpawnField(ReflectedSlot, EF_CLASS, 0);
      if ProjectilePower = PIERCING_POWER_A then
      begin
        World.SetSpawnField(ReflectedSlot, EF_TOUCH_KIND,
          TOUCH_KIND_HURT_HARD);
        BoxPercent := REFLECT_BOX_STRONG;
      end
      else
      begin
        World.SetSpawnField(ReflectedSlot, EF_TOUCH_KIND, TOUCH_KIND_HURT);
        BoxPercent := REFLECT_BOX_WEAK;
      end;
      World.SetSpawnField(ReflectedSlot, EF_BOX_PCT_X, BoxPercent);
      World.SetSpawnField(ReflectedSlot, EF_BOX_PCT_Y, BoxPercent);
      World.SetSpawnField(ReflectedSlot, EF_INSET_PCT_X, BoxPercent);
      World.SetSpawnField(ReflectedSlot, EF_INSET_PCT_Y, BoxPercent);
      World.PlaySound(HitSound(E));
      World.DestroyEntity(Projectile^, False);
      Exit;
    end;

    if Vulnerability = VULN_SPIN then
    begin
      E.Raw[EF_SHOTS] := SPIN_MARK;
      Inc(E.Raw[EF_FACING], SPIN_TURN);
      if E.Raw[EF_FACING] > DIR_COUNT - 1 then
        Dec(E.Raw[EF_FACING], DIR_COUNT);
      World.PlaySound(HitSound(E));
      World.DestroyEntity(Projectile^, False);
      Exit;
    end;

    if Vulnerability = VULN_SHOVE then
    begin
      { Convert horizontal velocity to a direction sign. }
      Direction := Compare(0, Projectile^.Raw[EF_VEL_X]);
      E.Raw[EF_VEL_X] := Direction shl SHOVE_SPEED_SHIFT;
      Inc(E.Raw[EF_FLAG1C], Compare(0, E.Raw[EF_VEL_X]));
      if E.Raw[EF_FLAG1C] > SHOVE_FRAMES - 1 then
        E.Raw[EF_FLAG1C] := 0;
      if E.Raw[EF_FLAG1C] < 0 then
        E.Raw[EF_FLAG1C] := SHOVE_FRAMES - 1;
      World.PlaySound(HitSound(E));
      World.DestroyEntity(Projectile^, False);
      Exit;
    end;

    { Immunity, some of it conditional on the shot's power. }
    if (Vulnerability = VULN_IMMUNE)
    or (Vulnerability = VULN_IMMUNE_ALT)
    or ((Vulnerability = VULN_ARMOUR_1) and (ProjectilePower < 1))
    or ((Vulnerability = VULN_ARMOUR_2) and (ProjectilePower < 2))
    or ((Vulnerability = VULN_ONLY_POWER3) and (ProjectilePower <> 3))
    or ((Vulnerability = VULN_ONLY_POWER4)
        and (ProjectilePower <> LOOT_POWER)) then
    begin
      World.PlaySound(HitSound(E));
      World.DestroyEntity(Projectile^, ProjectilePower = LOOT_POWER);
      Exit;
    end;

    { A real hit. The projectile's EF_HP is its DAMAGE - the same slot that
      holds hit points on a target. }
    Dec(E.Raw[EF_HP], Projectile^.Raw[EF_HP]);

    { Powers 2 and 3 pierce and are not consumed. }
    if (ProjectilePower <> PIERCING_POWER_A)
       and (ProjectilePower <> PIERCING_POWER_B) then
      World.DestroyEntity(Projectile^, ProjectilePower = LOOT_POWER);

    E.Raw[EF_TIMER] := HIT_INVULN;
    E.Raw[EF_DEATH_TIMER] := HIT_INVULN;

    if E.Raw[EF_HP] < 1 then
    begin
      E.Raw[EF_HP] := 0;
      E.Raw[EF_DYING] := 0;      { let Entity_UpdateDying run its setup }
    end
    else
      World.PlaySound(SND_HIT01);
    { NOTE: no Exit here. Only the special arms above stop the scan, so
      several shots can land in one pass until the target's HP reaches 0. }
  end;
end;

function IsAlive(const E: TEntity): Boolean;
begin
  Result := (E.Raw[EF_ALIVE] and $FF) = 1;
end;

{ Reads the contiguous sprite-data region, clamping indexes outside it. }
function SpriteDatum(Index: Integer): Integer;
begin
  { DIVERGENCE DIV-011: clamp only indexes outside the sprite-data region. }
  { Preserve cross-table reads within the region and clamp beyond its bounds. }
  if Index < 0 then
    Index := 0;
  if Index > High(SPRITE_DATA) then
    Index := High(SPRITE_DATA);
  Result := SPRITE_DATA[Index];
end;

function ScaleByPercent(Half, Percent: Integer): Integer;
var
  SignMultiplier, NormalizeShift, SignificandShift, BitIndex: Integer;
  Pow2Mod200, ErrorMagnitude, ScaledError, ValueExponent: Integer;
  ComparisonShift: Integer;
  Product, Quotient, Remainder, Remainder200, TwiceTie: Int64;
  LeftSide, RightSide: Int64;
begin
  SignMultiplier := 1;
  if Half < 0 then
  begin
    SignMultiplier := -1;
    Half := -Half;
  end;
  if Percent < 0 then
  begin
    SignMultiplier := -SignMultiplier;
    Percent := -Percent;
  end;
  if (Half = 0) or (Percent = 0) then
    Exit(0);

  Product := Int64(Half) * Percent;
  Quotient := Product div 100;
  Remainder := Product mod 100;
  if Remainder > 50 then
    Exit(SignMultiplier * Integer(Quotient + 1));
  if Remainder < 50 then
    Exit(SignMultiplier * Integer(Quotient));

  { --- a tie, and the only case where the FPU's own error decides -----------
    SignificandShift normalises Percent/100 to a 64-bit significand: starting
    with NormalizeShift such that
    100 <= Percent * 2^NormalizeShift < 200, then adding 63. }
  NormalizeShift := 0;
  if Percent < 100 then
    while (Int64(Percent) shl NormalizeShift) < 100 do
      Inc(NormalizeShift)
  else
    while (Int64(Percent) shr (-NormalizeShift)) >= 200 do
      Dec(NormalizeShift);
  SignificandShift := 63 + NormalizeShift;

  { ScaledError = D*100 - Percent*2^SignificandShift: the divide's rounding
    error scaled up. Its magnitude is at most 50 and can be derived from
    Percent*2^SignificandShift mod 200, avoiding a 128-bit product. Modulo 200
    rather than 100 carries the parity needed for a tie inside the tie. }
  Pow2Mod200 := 1;
  for BitIndex := 1 to SignificandShift do
    Pow2Mod200 := (Pow2Mod200 * 2) mod 200;
  Remainder200 := (Int64(Percent) * Pow2Mod200) mod 200;
  ErrorMagnitude := Integer(Remainder200 mod 100);
  if ErrorMagnitude < 50 then
    ScaledError := -ErrorMagnitude
  else if ErrorMagnitude > 50 then
    ScaledError := 100 - ErrorMagnitude
  else if Remainder200 >= 100 then
    ScaledError := 50
  else
    ScaledError := -50;

  if ScaledError <> 0 then
  begin
    { Compare |Half * ScaledError| / (100 * 2^SignificandShift) against half
      an ulp of V = Quotient + 1/2, which is 2^(ValueExponent - 64). Both
      sides scale to integers well inside Int64. }
    TwiceTie := 2 * Quotient + 1;
    ValueExponent := -1;
    while (Int64(1) shl (ValueExponent + 2)) <= TwiceTie do
      Inc(ValueExponent);
    ComparisonShift := SignificandShift + ValueExponent - 64;
    LeftSide := Abs(Int64(Half) * ScaledError);
    if ComparisonShift >= 0 then
      RightSide := Int64(100) shl ComparisonShift
    else
    begin
      LeftSide := LeftSide shl (-ComparisonShift);
      RightSide := 100;
    end;
    { Equality means the product landed exactly half an ulp off the tie. It
      occurs five times in the self-test domain and falls through because RN64
      breaks its own tie toward V's even significand. Writing >= here changes
      no tested answer; > is established by the derivation. }
    if LeftSide > RightSide then
    begin
      { The product landed off the tie, and the sign of the error decides. }
      if ScaledError > 0 then
        Exit(SignMultiplier * Integer(Quotient + 1))
      else
        Exit(SignMultiplier * Integer(Quotient));
    end;
  end;

  { The second rounding pulled the product back onto the tie exactly, so the
    final store rounds half to even. }
  if Quotient mod 2 = 0 then
    Result := SignMultiplier * Integer(Quotient)
  else
    Result := SignMultiplier * Integer(Quotient + 1);
end;

{ The type switch is separate so individual handlers can be tested without
  running a complete frame. }
procedure EntityRunHandler(var E: TEntity; var P: TPlayerState;
                           var L: TLayerInfo; var Inp: TInputState;
                           World: TEntityWorld; AGameState: Integer);
begin
  case E.Raw[EF_TYPE] of
    1:  PlayerUpdate(E, P, L, Inp, World, AGameState);
    14: EntityUpdate_Type14_ManaStone(E, AGameState);
    24: EntityUpdate_Type24_PowerOrb(E, AGameState, World);
    25: EntityUpdate_Type25_Door(E);
    27: EntityUpdate_Type27_AkujiStatue(E, AGameState);
    32: EntityUpdate_Type32_Emitter(E, AGameState, World);
    33: EntityUpdate_Type33_Explosion(E, AGameState, World);
    2:  EntityUpdate_Type02(E, AGameState, World);
    3:  EntityUpdate_Type03(E, AGameState, World);
    4:  EntityUpdate_Type04(E, AGameState, World);
    5:  EntityUpdate_Type05(E, AGameState, World);
    6:  EntityUpdate_Type06(E, AGameState, World);
    7:  EntityUpdate_Type07(E, AGameState, World);
    8:  EntityUpdate_Type08(E, AGameState, World);
    9:  EntityUpdate_Type09(E, AGameState);
    10: EntityUpdate_Type10(E, AGameState, World);
    11: EntityUpdate_Type11(E, AGameState);
    12: EntityUpdate_Type12(E, AGameState);
    13: EntityUpdate_Type13(E, AGameState, World);
    15: EntityUpdate_Type15_Switch(E, AGameState, World);
    17: EntityUpdate_Type17(E);
    19: EntityUpdate_Type19(E);
    21: EntityUpdate_Type21_WingedHorseBlock(E, AGameState, World);
    23: EntityUpdate_Type23_Candle(E, AGameState, World);
    28: EntityUpdate_Type28(E, AGameState, World);
    29: EntityUpdate_Type29_Mon_MidoriMonster(E, AGameState, World);
    30: EntityUpdate_Type30_Akuji(E, AGameState, World);
    31: EntityUpdate_Type31_Boss_MurasakiLizard(E, AGameState, World);
    34: EntityUpdate_Type34(E, AGameState, World);
    35: EntityUpdate_Type35(E, AGameState, World);
    37: EntityUpdate_Type37_BossKey(E, AGameState, World);
    38: EntityUpdate_Type38_Mon_AkuNeko(E, AGameState, World);
    39: EntityUpdate_Type39(E, AGameState, World);
    40: EntityUpdate_Type40_PoyoPoyo(E, AGameState, Inp, World);
    41: EntityUpdate_Type41_Mon_TondaCricket(E, AGameState, World);
    42: EntityUpdate_Type42_Boss_TealBlobSlammer(E, AGameState, World);
    43: EntityUpdate_Type43_GashiGashi(E, AGameState, World);
    44: EntityUpdate_Type44(E, AGameState, World);
    45: EntityUpdate_Type45_Block_NukeNuke(E, AGameState, World);
    46: EntityUpdate_Type46_Mon_Bat(E, AGameState, World);
    47: EntityUpdate_Type47_Mon_PinkSquid(E, AGameState, World);
    48: EntityUpdate_Type48(E, AGameState, World);
    49: EntityUpdate_Type49_Mon_Water(E, AGameState, World);
    50: EntityUpdate_Type50_Mon_Turtle(E, AGameState, World);
    51: EntityUpdate_Type51_Mon_Ghost(E, AGameState, World);
    53: EntityUpdate_Type53(E, AGameState, World);
    56: EntityUpdate_Type56_Mon_AkaiKinoko(E, AGameState, World);
    52: EntityUpdate_Type52_Boss_FireLion(E, AGameState, World);
    54: EntityUpdate_Type54_Boss_FloatingMagician(E, AGameState, World);
    55: EntityUpdate_Type55(E, AGameState, World);
    57: EntityUpdate_Type57(E, AGameState, World);
    58: EntityUpdate_Type58_Mon_NiseMana(E, AGameState, World);
    59: EntityUpdate_Type59_Mon_RedEye(E, AGameState, World);
    60: EntityUpdate_Type60_Mon_Golem(E, AGameState, World);
    61: EntityUpdate_Type61_Mon_HenaHena(E, AGameState, World);
    62: EntityUpdate_Type62_Mon_PenguinHeishi(E, AGameState, World);
    63: EntityUpdate_Type63_Mon_PenguinKnife(E, AGameState, World);
    64: EntityUpdate_Type64_SpikePress(E, AGameState, World);
    65: EntityUpdate_Type65_Mon_DorDor(E, AGameState, Inp, World);
    66: EntityUpdate_Type66_GiantBall(E, AGameState, World);
    67: EntityUpdate_Type67_Mon_TurtleBomb(E, AGameState, World);
    68: EntityUpdate_Type68(E, AGameState, World);
    69: EntityUpdate_Type69_GoroGoro(E, AGameState, World);
    70: EntityUpdate_Type70_AngrySwitch(E, AGameState, World);
    71: EntityUpdate_Type71_BouncyCat(E, AGameState, World);
    72: EntityUpdate_Type72(E, AGameState, World);
    73: EntityUpdate_Type73_Boss_MidoriLizard(E, AGameState, World);
    74: EntityUpdate_Type74(E, AGameState, World);
    75: EntityUpdate_Type75(E, AGameState, World);
    76: EntityUpdate_Type76_SpikePress_Lev(E, AGameState, World);
    77: EntityUpdate_Type77_Boss_Hero(E, AGameState, World);
    78: EntityUpdate_Type78(E, AGameState, World);
    79: EntityUpdate_Type79(E, AGameState, World);
    80: EntityUpdate_Type80_Fx_ArenaEmber(E, AGameState, World);
    16: EntityUpdate_Type16_InfoSign(E);
    22: EntityUpdate_Type22_SpikeBall(E, AGameState, World);
    26: EntityUpdate_Type26(E, AGameState, World);
    36: EntityUpdate_Type36_FallingItem(E, AGameState, World);
    { DIVERGENCE DIV-006: count otherwise-unhandled types for coverage checks. }
    { Count unexpected types for dispatch coverage checks. }
  else
    Inc(EntitiesUnhandled);
  end;
end;

procedure EntityUpdateAll(Pool: TEntityPool; World: TEntityWorld;
                          Sprites: TSpriteSink;
                          var P: TPlayerState; var L: TLayerInfo;
                          var Inp: TInputState; var AGameState: Integer);
var
  EntitySlot, SpriteHandle, ScreenX, ScreenY, Depth: Integer;
  HalfWidth, HalfHeight: Integer;
  EntityPtr: PEntity;
begin
  EntitiesDrawn := 0;
  EntitiesLive  := 0;

  for EntitySlot := 0 to ENTITY_UPDATE_COUNT - 1 do
  begin
    EntityPtr := Pool.Entity(EntitySlot);
    if not IsAlive(EntityPtr^) then
      Continue;
    Inc(EntitiesLive);

    { Carried along by the scroll unless the type is screen-space. This is why
      a HUD element placed as an entity stays put while the map moves under it. }
    if EntityPtr^.Raw[EF_SCREEN_SPACE] = 0 then
    begin
      Inc(EntityPtr^.Raw[EF_POS_X], L.DeltaX);
      Inc(EntityPtr^.Raw[EF_POS_Y], L.DeltaY);
    end;

    EntityRunHandler(EntityPtr^, P, L, Inp, World, AGameState);

    { --- push the entity onto its sprite ---------------------------------
      Skipped entirely for a type with no sprite, and re-tests aliveness
      because the handler above may have destroyed the entity. }
    SpriteHandle := EntityPtr^.Raw[EF_SPRITE];
    if (SpriteHandle <> SPRITE_NONE) and IsAlive(EntityPtr^) then
    begin
      Inc(EntitiesDrawn);

      { The death timer doubles as the damage flicker: while it is ODD the
        sprite is hidden, so an entity blinks for as long as it is counting
        down. On even frames the sprite takes EF_BYTE94 verbatim - a byte copy,
        so it is that field and not a normalised boolean that decides
        visibility. }
      if EntityPtr^.Raw[EF_DEATH_TIMER] mod 2 = 0 then
        Sprites.SetVisible(SpriteHandle,
          (EntityPtr^.Raw[EF_BYTE94] and $FF) <> 0)
      else
        Sprites.SetVisible(SpriteHandle, False);

      Sprites.SetAnim(SpriteHandle, EntityPtr^.Raw[EF_ANIM_ID]);

      { Extents refresh only while visible, so a hidden entity keeps the size it
        had when it was last drawn - and keeps colliding at that size. }
      if Sprites.GetVisible(SpriteHandle) then
      begin
        EntityPtr^.Raw[EF_EXTENT_X] := Sprites.Width(SpriteHandle);
        EntityPtr^.Raw[EF_EXTENT_Y] := Sprites.Height(SpriteHandle);
      end;

      { The sprite is placed by its top-left, the entity by its CENTRE: half the
        sprite comes off each axis. That is what fixes an entity position as a
        centre point rather than a corner. }
      ScreenX := OriginPixel(EntityPtr^.Raw[EF_POS_X]) - POSITION_BIAS_PIXELS
                 - HalfExtent(EntityPtr^.Raw[EF_EXTENT_X]);
      ScreenY := OriginPixel(EntityPtr^.Raw[EF_POS_Y]) - POSITION_BIAS_PIXELS
                 - HalfExtent(EntityPtr^.Raw[EF_EXTENT_Y]);
      Sprites.SetPos(SpriteHandle, ScreenX, ScreenY);

      Depth := EntityPtr^.Raw[EF_DEPTH];
      if Depth = DEPTH_BY_SCREEN_Y then
      begin
        Depth := ScreenY;
        if Depth < 1 then Depth := 1;
        if Depth > SCREEN_H then Depth := SCREEN_H;
      end;
      Sprites.SetDepth(SpriteHandle, Depth);
    end;

    { --- the two timers -------------------------------------------------
      Frozen during the pause menu and during state 140, which is what makes a
      paused invulnerability or a paused death animation hold. }
    if (AGameState <> GS_PAUSE) and (AGameState <> GS_STATE_140) then
    begin
      if EntityPtr^.Raw[EF_TIMER] <> 0 then
        Dec(EntityPtr^.Raw[EF_TIMER]);
      if EntityPtr^.Raw[EF_DEATH_TIMER] <> 0 then
        Dec(EntityPtr^.Raw[EF_DEATH_TIMER]);
    end;

    if AGameState <> GS_PLAY then
      Continue;

    { --- collision boxes, rebuilt from the sprite size ------------------- }
    HalfWidth := HalfExtent(EntityPtr^.Raw[EF_EXTENT_X]);
    HalfHeight := HalfExtent(EntityPtr^.Raw[EF_EXTENT_Y]);
    EntityPtr^.Raw[EF_BOX_OFS_X] :=
      ScaleByPercent(HalfWidth, EntityPtr^.Raw[EF_BOX_PCT_X]);
    EntityPtr^.Raw[EF_BOX_OFS_Y] :=
      ScaleByPercent(HalfHeight, EntityPtr^.Raw[EF_BOX_PCT_Y]);
    EntityPtr^.Raw[EF_HITBOX_INSET_X] :=
      ScaleByPercent(HalfWidth, EntityPtr^.Raw[EF_INSET_PCT_X]);
    EntityPtr^.Raw[EF_HITBOX_INSET_Y] :=
      ScaleByPercent(HalfHeight, EntityPtr^.Raw[EF_INSET_PCT_Y]);

    { Only the minor slots are touch-tested and shot-tested. The player and the
      actors below SLOT_MINOR_FIRST are not, which is the same boundary
      Entity_TakeProjectileHits scans up to from the other side. }
    if (EntitySlot >= SLOT_MINOR_FIRST) and IsAlive(EntityPtr^) then
    begin
      if Assigned(EntityPlayerTouch) then
        EntityPlayerTouch(EntityPtr^, Pool.Entity(0)^, P, Inp, World);
      if Assigned(EntityTakeProjectileHits) then
        EntityTakeProjectileHits(EntityPtr^, World);
    end;

    if (EntityPtr^.Raw[EF_TYPE] = TYPE_TOUCH_IN_STATE_3)
       and (EntityPtr^.Raw[EF_STATE] = 3) and IsAlive(EntityPtr^) then
      if Assigned(EntityPlayerTouch) then
        EntityPlayerTouch(EntityPtr^, Pool.Entity(0)^, P, Inp, World);

    { A touch that changes game state abandons the remaining entity updates for
      this frame. }
    if (AGameState <> GS_PLAY) and (AGameState <> GS_STATE_140) then
      Exit;

    if IsAlive(EntityPtr^) and (EntityPtr^.Raw[EF_CULL_OFFSCREEN] = 1)
       and IsOffScreen(EntityPtr^, CULL_MARGIN) then
      World.DestroyEntity(EntityPtr^, False);
  end;
end;

{ SPRITE_DATA and the per-type tables are two views of the same sprite region,
  and four handlers read across a table's end into the next one. If the two
  views ever disagree those reads go somewhere else and all four handlers are
  wrong at once, with nothing else to notice.

  Checked at startup rather than in a self-test for that reason, and `if ...
  raise` rather than `Assert`: FPC compiles assertions out unless -Sa is
  passed, which this project does not pass. }
procedure CheckSpriteData;

  procedure Same(const Name: string; At: Integer; const Want: array of Integer);
  var
    ValueIndex: Integer;
  begin
    for ValueIndex := 0 to High(Want) do
      if SPRITE_DATA[At + ValueIndex] <> Want[ValueIndex] then
        raise Exception.CreateFmt(
          '%s[%d] is %d but SPRITE_DATA at 0x%.8x is %d - the region and the '
          + 'tables have been edited apart', [Name, ValueIndex,
          Want[ValueIndex], SPRITE_DATA_BASE + 4 * (At + ValueIndex),
          SPRITE_DATA[At + ValueIndex]]);
  end;

begin
  Same('T2_SPRITES', T2_AT, [T2_SPRITES[0][0], T2_SPRITES[0][1],
       T2_SPRITES[0][2], T2_SPRITES[0][3], T2_SPRITES[1][0]]);
  Same('T7_SPRITES', T7_AT, [T7_SPRITES[0][0], T7_SPRITES[0][1],
       T7_SPRITES[0][2], T7_SPRITES[0][3], T7_SPRITES[1][0]]);
  Same('MANA_SPRITES', MANA_AT, [MANA_SPRITES[0][0], MANA_SPRITES[0][1],
       MANA_SPRITES[0][2], MANA_SPRITES[0][3], MANA_SPRITES[1][0]]);
  Same('T38_SPRITES', T38_AT, [T38_SPRITES[0][0], T38_SPRITES[0][1],
       T38_SPRITES[0][2], T38_SPRITES[0][3], T38_SPRITES[1][0]]);
end;

initialization
  CheckSpriteData;
  { The touch pass is real now. It stays a variable only so a test can put a
    counting stub in its place. }
  EntityPlayerTouch := @PlayerTouch;
  EntityTakeProjectileHits := @TakeProjectileHits;

end.
