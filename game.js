const TARGET_DISTANCE = 19500;
const TILE_SIZE = 48;
const WORLD_COLUMNS = 28;
const WORLD_ROWS = 7;
const GRAVITY = 2200;
const JUMP_VELOCITY = -760;
const MIN_OBSTACLE_GAP = 12;
const MAX_OBSTACLE_GAP = 20;
const START_OBSTACLE_GAP_MIN = 18;
const START_OBSTACLE_GAP_MAX = 26;
const END_OBSTACLE_GAP_MIN = 8;
const END_OBSTACLE_GAP_MAX = 12;
const START_SPEED = 320;
const MAX_SPEED = 560;
const SPEED_RAMP = 90;
const CLIENTS_PER_PIXEL = 0.68;
const BUG_WIDTH = TILE_SIZE * 0.9;
const BUG_HEIGHT = TILE_SIZE * 0.7;
const DEAD_BUG_HEIGHT = TILE_SIZE * 0.34;
const BUG_SPEED_MIN = 74;
const BUG_SPEED_MAX = 112;
const BUG_PATROL_MARGIN = 12;
const MIN_BUG_PATROL_WIDTH = TILE_SIZE * 2.5;
const STOMP_BOUNCE_VELOCITY = -440;
const STOMP_DESCENT_ALLOWANCE = -260;
const STOMP_APPROACH_HEIGHT = BUG_HEIGHT * 1.12;
const STOMP_VERTICAL_OVERLAP_LIMIT = BUG_HEIGHT * 1.02;
const STOMP_HORIZONTAL_TOLERANCE = BUG_WIDTH * 0.12;
const STOMP_AIRBORNE_BUFFER = 2;
const BUG_ANIMATION_FRAME_WIDTH = 24;
const BUG_ANIMATION_FRAME_HEIGHT = 18;
const BUG_ANIMATION_FRAMES = 4;
const BUG_ANIMATION_SPEED_MS = 120;
const PLAYER_DEATH_FRAME_WIDTH = 32;
const PLAYER_DEATH_FRAME_HEIGHT = 32;
const PLAYER_DEATH_FRAMES = 4;
const PLAYER_DEATH_FRAME_MS = 110;
const PLAYER_DEATH_INPUT_LOCK_MS = 2000;
const OUTAGE_WIDTH = TILE_SIZE * 2.55;
const OUTAGE_HEIGHT = TILE_SIZE * 1.3;
const OUTAGE_VERTICAL_OFFSET = TILE_SIZE * 1.35;
const OUTAGE_MIN_WORLD_GAP = TILE_SIZE * 8.5;
const OUTAGE_SPAWN_CHECK_MIN = 2.1;
const OUTAGE_SPAWN_CHECK_MAX = 5.3;
const OUTAGE_DROP_INTERVAL_MIN = 0.65;
const OUTAGE_DROP_INTERVAL_MAX = 1.3;
const FIREBALL_FRAME_WIDTH = 16;
const FIREBALL_FRAME_HEIGHT = 24;
const FIREBALL_FRAMES = 4;
const FIREBALL_FRAME_MS = 90;
const FIREBALL_WIDTH = TILE_SIZE * 0.7;
const FIREBALL_HEIGHT = TILE_SIZE * 1.05;
const FIREBALL_FALL_SPEED_MIN = 430;
const FIREBALL_FALL_SPEED_MAX = 580;
const FIREBALL_IMPACT_EFFECT_MS = 260;
const FIREBALL_IMPACT_RADIUS = TILE_SIZE * 1.15;
const FIREBALL_IMPACT_GROUND_CLEARANCE = TILE_SIZE * 0.72;
const GROUND_TRANSITION_HEIGHT = TILE_SIZE;
const GROUND_TRANSITION_OVERLAP = TILE_SIZE * 0.75;
const PARALLAX_GAP_SCALE = 0.75;
const HIGH_SCORE_STORAGE_KEY = "jerzy-interes-high-score";
const GOOD_CLOUD_WIDTH = TILE_SIZE * 2.45;
const GOOD_CLOUD_HEIGHT = TILE_SIZE * 1.22;
const GOOD_CLOUD_VERTICAL_OFFSET = TILE_SIZE * 1.12;
const GOOD_CLOUD_MIN_WORLD_GAP = TILE_SIZE * 15;
const GOOD_CLOUD_SPAWN_CHECK_MIN = 5.4;
const GOOD_CLOUD_SPAWN_CHECK_MAX = 9.2;
const GOOD_CLOUD_COLLISION_PADDING_X = TILE_SIZE * 0.18;
const GOOD_CLOUD_COLLISION_PADDING_Y = TILE_SIZE * 0.14;
const PLAYER_IMMUNITY_DURATION_MS = 10000;
const defeatConfigs = {
  blocker: {
    kicker: "Run ended",
    title: "A blocker stopped the migration",
    summary: "A blocker forced the rollout to stop",
  },
  bug: {
    kicker: "Run ended",
    title: "A bug interrupted the migration",
    summary: "A bug caught the team mid-rollout",
  },
  outage: {
    kicker: "Run ended",
    title: "A system outage killed the migration",
    summary: "A fireball from a system outage took down the rollout",
  },
  generic: {
    kicker: "Run ended",
    title: "The migration run stopped",
    summary: "The rollout hit a problem",
  },
};

const canvas = document.getElementById("gameCanvas");
const ctx = canvas.getContext("2d");
const distanceValue = document.getElementById("distanceValue");
const progressValue = document.getElementById("progressValue");
const highScoreValue = document.getElementById("highScoreValue");
const overlay = document.getElementById("overlay");
const overlayKicker = document.getElementById("overlayKicker");
const overlayTitle = document.getElementById("overlayTitle");
const overlayText = document.getElementById("overlayText");
const actionButton = document.getElementById("actionButton");
const playArea = document.querySelector(".play-area");
const appShell = document.querySelector(".app");
const gameShell = document.querySelector(".game-shell");
const hud = document.querySelector(".hud");
const controls = document.querySelector(".controls");

const tileImages = {
  floorTop: new Image(),
  floorBase: new Image(),
  obstacle: new Image(),
};
const bugImages = {
  alive: new Image(),
  dead: new Image(),
};
const outageImages = {
  cloud: new Image(),
  fireball: new Image(),
};
const supportImages = {
  sky: new Image(),
  goodCloud: new Image(),
  groundTransition: new Image(),
};

tileImages.floorTop.src = "assets/tile-floor-top.png";
tileImages.floorBase.src = "assets/tile-floor-base.png";
tileImages.obstacle.src = "assets/tile-obstacle.png";
bugImages.alive.src = "assets/bug-walker-sprite.png";
bugImages.dead.src = "assets/bug-walker-dead.png";
outageImages.cloud.src = "assets/outage-cloud.png";
outageImages.fireball.src = "assets/fireball-sprite.png";
supportImages.sky.src = "assets/bg-sky.png";
supportImages.goodCloud.src = "assets/good-cloud.png";
supportImages.groundTransition.src = "assets/ground-transition.png";

const playerSprite = new Image();
const playerDeathSprite = new Image();
playerSprite.src = "assets/player-runner-sprite.png";
playerDeathSprite.src = "assets/player-death-sprite.png";

const playerFrames = {
  run: [0, 1, 2],
  jump: 3,
};
const spriteFrameWidth = 32;
const spriteFrameHeight = 32;
const MOBILE_LAYOUT_BREAKPOINT = 720;
const MIN_MOBILE_PLAY_AREA_HEIGHT = 220;
const deliveryOptionsPath = "assets/delivery-options.json";
const outageReasonsPath = "assets/outage-reasons.json";
const clientFeedbackPath = "assets/client-feedback.json";
const defaultDeliveryOptions = [
  "Client Migration",
  "Data Migration",
  "Payments Readiness",
  "Training Materials",
];
const defaultOutageReasons = [
  "Core API outage",
  "Certificate expired",
  "Database failover issue",
  "Payment gateway downtime",
  "Identity service disruption",
  "Broken production deployment",
];
const defaultClientFeedbackOptions = [
  "The new dashboard is much clearer",
  "Migration went smoothly for our team",
  "Payments feel faster already",
  "Onboarding was surprisingly easy",
  "Support docs finally make sense",
  "We can do our daily work quicker now",
];
let deliveryOptions = [...defaultDeliveryOptions];
let outageReasons = [...defaultOutageReasons];
let clientFeedbackOptions = [...defaultClientFeedbackOptions];

const backgroundLayers = [
  {
    image: new Image(),
    src: "assets/bg-parallax-far.png",
    speed: 0.12,
    height: 150,
    bottomGap: 130,
    fallback: "rgba(145, 173, 191, 0.4)",
  },
  {
    image: new Image(),
    src: "assets/bg-parallax-mid.png",
    speed: 0.22,
    height: 146,
    bottomGap: 92,
    fallback: "rgba(92, 119, 120, 0.5)",
  },
  {
    image: new Image(),
    src: "assets/bg-parallax-near.png",
    speed: 0.36,
    height: 132,
    bottomGap: 48,
    fallback: "rgba(72, 102, 58, 0.65)",
  },
];
const BASE_PARALLAX_BOTTOM_GAP = Math.min(...backgroundLayers.map((layer) => layer.bottomGap ?? 0));
const obstaclePatterns = [
  {
    cells: [1],
    minDifficulty: 0,
    startWeight: 1.2,
    endWeight: 0.45,
  },
  {
    cells: [1, 0, 1],
    minDifficulty: 0.08,
    startWeight: 0.18,
    endWeight: 0.95,
  },
  {
    cells: [1, 1],
    minDifficulty: 0.22,
    startWeight: 0.08,
    endWeight: 0.72,
  },
  {
    cells: [1, 0, 1, 0, 1],
    minDifficulty: 0.42,
    startWeight: 0.02,
    endWeight: 0.42,
  },
  {
    cells: [1, 1, 0, 1],
    minDifficulty: 0.5,
    startWeight: 0.02,
    endWeight: 0.5,
  },
  {
    cells: [1, 0, 1, 1],
    minDifficulty: 0.62,
    startWeight: 0.01,
    endWeight: 0.44,
  },
];

for (const layer of backgroundLayers) {
  layer.image.src = layer.src;
}

const state = {
  phase: "idle",
  lastTime: 0,
  distance: 0,
  speed: START_SPEED,
  offsetX: 0,
  worldScroll: 0,
  worldColumnOffset: 0,
  nextWorldColumnIndex: 0,
  lastObstacleColumn: null,
  nextObstacleInTiles: 14,
  pendingObstaclePattern: [],
  highScore: 0,
  columns: [],
  bugs: [],
  outages: [],
  fireballs: [],
  goodClouds: [],
  nextOutageCheckIn: 0,
  nextGoodCloudCheckIn: 0,
  lastOutageWorldX: -Infinity,
  lastGoodCloudWorldX: -Infinity,
  player: {
    width: TILE_SIZE * 0.8,
    height: TILE_SIZE * 1.15,
    x: TILE_SIZE * 3,
    y: 0,
    previousY: 0,
    deathStartedAt: null,
    immunityUntil: 0,
    velocityY: 0,
    grounded: true,
  },
};

const worldTop = () => canvas.height - WORLD_ROWS * TILE_SIZE - TILE_SIZE;
const groundRow = () => WORLD_ROWS - 2;
const groundSurfaceY = () => worldTop() + groundRow() * TILE_SIZE;
const backgroundStartY = () => groundSurfaceY() - GROUND_TRANSITION_HEIGHT;
const playerBaseY = () => groundSurfaceY() - state.player.height;

function drawRoundedRect(x, y, width, height, radius) {
  ctx.beginPath();

  if (typeof ctx.roundRect === "function") {
    ctx.roundRect(x, y, width, height, radius);
    return;
  }

  const safeRadius = Math.min(radius, width / 2, height / 2);
  ctx.moveTo(x + safeRadius, y);
  ctx.arcTo(x + width, y, x + width, y + height, safeRadius);
  ctx.arcTo(x + width, y + height, x, y + height, safeRadius);
  ctx.arcTo(x, y + height, x, y, safeRadius);
  ctx.arcTo(x, y, x + width, y, safeRadius);
  ctx.closePath();
}

function getTileRect(columnIndex, rowIndex) {
  return {
    x: Math.round(columnIndex * TILE_SIZE - state.offsetX),
    y: Math.round(worldTop() + rowIndex * TILE_SIZE),
    width: TILE_SIZE,
    height: TILE_SIZE,
  };
}

function getCellType(cell) {
  if (!cell) {
    return null;
  }

  return typeof cell === "string" ? cell : cell.type;
}

function randomItem(items) {
  return items[Math.floor(Math.random() * items.length)];
}

function createObstacleCell() {
  return {
    type: "obstacle",
    label: randomItem(deliveryOptions),
  };
}

function createBugBetweenObstacles(
  leftObstacleColumn,
  rightObstacleColumn,
  progress = getProgressRatio()
) {
  if (leftObstacleColumn === null) {
    return null;
  }

  const patrolStart = (leftObstacleColumn + 1) * TILE_SIZE + BUG_PATROL_MARGIN;
  const patrolEnd = rightObstacleColumn * TILE_SIZE - BUG_WIDTH - BUG_PATROL_MARGIN;
  const bugSpawnChance = lerp(0.16, 0.94, getDifficultyProgress(progress));

  if (patrolEnd - patrolStart < MIN_BUG_PATROL_WIDTH || Math.random() > bugSpawnChance) {
    return null;
  }

  return {
    state: "alive",
    worldX: (patrolStart + patrolEnd) / 2,
    patrolStart,
    patrolEnd,
    direction: Math.random() < 0.5 ? -1 : 1,
    speed: randomInt(BUG_SPEED_MIN, BUG_SPEED_MAX),
  };
}

function getProgressRatio() {
  return clamp(state.distance / TARGET_DISTANCE, 0, 1);
}

function getDifficultyProgress(progress = getProgressRatio()) {
  return clamp(progress ** 1.18, 0, 1);
}

function lerp(start, end, amount) {
  return start + (end - start) * amount;
}

function getObstacleGapRange(progress = getProgressRatio()) {
  const difficulty = getDifficultyProgress(progress);
  const minGap = Math.round(lerp(START_OBSTACLE_GAP_MIN, END_OBSTACLE_GAP_MIN, difficulty));
  const maxGap = Math.round(lerp(START_OBSTACLE_GAP_MAX, END_OBSTACLE_GAP_MAX, difficulty));

  return {
    min: Math.min(minGap, maxGap),
    max: Math.max(minGap, maxGap),
  };
}

function getRandomObstacleGapTiles(progress = getProgressRatio()) {
  const gapRange = getObstacleGapRange(progress);
  const difficulty = getDifficultyProgress(progress);
  const widenedMin = Math.max(4, gapRange.min - (difficulty > 0.5 ? 1 : 0));
  const widenedMax = gapRange.max + (difficulty < 0.38 ? 2 : 1);
  let nextGap = randomInt(widenedMin, widenedMax);

  if (Math.random() < lerp(0.12, 0.32, difficulty)) {
    nextGap += randomInt(-2, 2);
  }

  return clamp(nextGap, widenedMin, widenedMax);
}

function getObstaclePatternWeight(pattern, difficulty) {
  if (difficulty < pattern.minDifficulty) {
    return 0;
  }

  const ramp = clamp((difficulty - pattern.minDifficulty) / Math.max(0.08, 1 - pattern.minDifficulty), 0, 1);
  return lerp(pattern.startWeight, pattern.endWeight, ramp);
}

function chooseObstaclePattern(progress = getProgressRatio()) {
  const difficulty = getDifficultyProgress(progress);
  const weightedPatterns = obstaclePatterns
    .map((pattern) => ({
      pattern,
      weight: getObstaclePatternWeight(pattern, difficulty),
    }))
    .filter((entry) => entry.weight > 0);

  if (!weightedPatterns.length) {
    return obstaclePatterns[0].cells.slice();
  }

  const totalWeight = weightedPatterns.reduce((sum, entry) => sum + entry.weight, 0);
  let target = Math.random() * totalWeight;

  for (const entry of weightedPatterns) {
    target -= entry.weight;
    if (target <= 0) {
      return entry.pattern.cells.slice();
    }
  }

  return weightedPatterns[weightedPatterns.length - 1].pattern.cells.slice();
}

function getOutageDropInterval(progress) {
  const minInterval = Math.max(0.52, OUTAGE_DROP_INTERVAL_MIN - progress * 0.12);
  const maxInterval = Math.max(minInterval + 0.18, OUTAGE_DROP_INTERVAL_MAX - progress * 0.16);
  return randomFloat(minInterval, maxInterval);
}

function createOutage(progress) {
  return {
    worldX: state.worldScroll + canvas.width + randomFloat(TILE_SIZE * 1.8, TILE_SIZE * 5.2),
    y: worldTop() - OUTAGE_VERTICAL_OFFSET + randomFloat(-TILE_SIZE * 0.12, TILE_SIZE * 0.08),
    bobPhase: randomFloat(0, Math.PI * 2),
    nextDropIn: getOutageDropInterval(progress),
    remainingDrops: randomInt(1, progress > 0.62 ? 3 : 2),
  };
}

function createGoodCloud() {
  return {
    worldX: state.worldScroll + canvas.width + randomFloat(TILE_SIZE * 2.4, TILE_SIZE * 5.6),
    y:
      worldTop() +
      GOOD_CLOUD_VERTICAL_OFFSET +
      randomFloat(-TILE_SIZE * 0.16, TILE_SIZE * 0.18),
    bobPhase: randomFloat(0, Math.PI * 2),
    feedback: randomItem(clientFeedbackOptions),
  };
}

function scheduleNextOutageCheck(progress = getProgressRatio()) {
  const minDelay = Math.max(1.45, OUTAGE_SPAWN_CHECK_MIN - progress * 0.35);
  const maxDelay = Math.max(minDelay + 0.8, OUTAGE_SPAWN_CHECK_MAX - progress * 1.15);
  state.nextOutageCheckIn = randomFloat(minDelay, maxDelay);
}

function scheduleNextGoodCloudCheck() {
  state.nextGoodCloudCheckIn = randomFloat(GOOD_CLOUD_SPAWN_CHECK_MIN, GOOD_CLOUD_SPAWN_CHECK_MAX);
}

function maybeSpawnOutage(delta) {
  state.nextOutageCheckIn -= delta;
  if (state.nextOutageCheckIn > 0) {
    return;
  }

  const progress = getProgressRatio();
  scheduleNextOutageCheck(progress);

  if (Math.random() > 0.16 + progress * 0.52) {
    return;
  }

  if (state.worldScroll + canvas.width - state.lastOutageWorldX < OUTAGE_MIN_WORLD_GAP) {
    return;
  }

  const outage = createOutage(progress);
  state.lastOutageWorldX = outage.worldX;
  state.outages.push(outage);
}

function maybeSpawnGoodCloud(delta) {
  state.nextGoodCloudCheckIn -= delta;
  if (state.nextGoodCloudCheckIn > 0) {
    return;
  }

  scheduleNextGoodCloudCheck();

  if (Math.random() > 0.28) {
    return;
  }

  if (state.worldScroll + canvas.width - state.lastGoodCloudWorldX < GOOD_CLOUD_MIN_WORLD_GAP) {
    return;
  }

  const goodCloud = createGoodCloud();
  state.lastGoodCloudWorldX = goodCloud.worldX;
  state.goodClouds.push(goodCloud);
}

function createEmptyColumn() {
  return Array.from({ length: WORLD_ROWS }, (_, row) => {
    if (row === groundRow()) {
      return "floorTop";
    }

    if (row > groundRow()) {
      return "floorBase";
    }

    return null;
  });
}

function createGeneratedColumn(worldColumnIndex) {
  const column = createEmptyColumn();
  const progress = getProgressRatio();

  if (state.pendingObstaclePattern.length > 0) {
    const nextPatternTile = state.pendingObstaclePattern.shift();
    if (nextPatternTile) {
      column[groundRow() - 1] = createObstacleCell();
    }
    return column;
  }

  if (worldColumnIndex > 10 && state.nextObstacleInTiles <= 0) {
    const pattern = chooseObstaclePattern(progress);
    const lastObstacleOffset = Math.max(
      0,
      pattern.reduce((lastIndex, cell, index) => (cell ? index : lastIndex), 0)
    );
    const bug = createBugBetweenObstacles(state.lastObstacleColumn, worldColumnIndex, progress);
    if (bug) {
      state.bugs.push(bug);
    }

    column[groundRow() - 1] = createObstacleCell();
    state.lastObstacleColumn = worldColumnIndex + lastObstacleOffset;
    state.pendingObstaclePattern = pattern.slice(1);
    state.nextObstacleInTiles = getRandomObstacleGapTiles(progress);
  } else {
    state.nextObstacleInTiles -= 1;
  }

  return column;
}

function buildInitialWorld() {
  state.columns = [];
  state.bugs = [];
  state.worldColumnOffset = 0;
  state.nextWorldColumnIndex = 0;
  state.lastObstacleColumn = null;
  for (let index = 0; index < WORLD_COLUMNS + 4; index += 1) {
    state.columns.push(createGeneratedColumn(state.nextWorldColumnIndex));
    state.nextWorldColumnIndex += 1;
  }
}

function resetGame() {
  state.phase = "idle";
  state.lastTime = 0;
  state.distance = 0;
  state.speed = START_SPEED;
  state.offsetX = 0;
  state.worldScroll = 0;
  state.worldColumnOffset = 0;
  state.nextWorldColumnIndex = 0;
  state.lastObstacleColumn = null;
  state.nextObstacleInTiles = getRandomObstacleGapTiles(0);
  state.pendingObstaclePattern = [];
  state.outages = [];
  state.fireballs = [];
  state.goodClouds = [];
  state.nextOutageCheckIn = randomFloat(OUTAGE_SPAWN_CHECK_MIN, OUTAGE_SPAWN_CHECK_MAX);
  state.nextGoodCloudCheckIn = randomFloat(GOOD_CLOUD_SPAWN_CHECK_MIN, GOOD_CLOUD_SPAWN_CHECK_MAX);
  state.lastOutageWorldX = -Infinity;
  state.lastGoodCloudWorldX = -Infinity;
  state.player.y = playerBaseY();
  state.player.previousY = playerBaseY();
  state.player.deathStartedAt = null;
  state.player.immunityUntil = 0;
  state.player.velocityY = 0;
  state.player.grounded = true;
  buildInitialWorld();
  updateHud();
  setOverlay({
    hidden: false,
    kicker: "Tap or press Space",
    title: "Start the migration run",
    text: "Jump over blockers and help migrate 19,500 clients to the new IB George Business.",
    button: "Start",
  });
}

function setOverlay({ hidden, kicker, title, text, button }) {
  overlay.hidden = hidden;
  overlayKicker.textContent = kicker;
  overlayTitle.textContent = title;
  overlayText.textContent = text;
  actionButton.textContent = button;
  syncActionButtonState();
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomFloat(min, max) {
  return Math.random() * (max - min) + min;
}

function syncPlayAreaToViewport() {
  if (!playArea || !appShell || !gameShell || !hud || !controls) {
    return;
  }

  if (window.innerWidth > MOBILE_LAYOUT_BREAKPOINT) {
    playArea.style.removeProperty("height");
    return;
  }

  const appStyles = window.getComputedStyle(appShell);
  const shellStyles = window.getComputedStyle(gameShell);
  const paddingTop = parseFloat(appStyles.paddingTop) || 0;
  const paddingBottom = parseFloat(appStyles.paddingBottom) || 0;
  const paddingLeft = parseFloat(appStyles.paddingLeft) || 0;
  const paddingRight = parseFloat(appStyles.paddingRight) || 0;
  const rowGap = parseFloat(shellStyles.rowGap || shellStyles.gap) || 0;
  const availableWidth = Math.max(0, window.innerWidth - paddingLeft - paddingRight);
  const availableHeight =
    window.innerHeight -
    paddingTop -
    paddingBottom -
    hud.offsetHeight -
    controls.offsetHeight -
    rowGap * 2;
  const aspectHeight = availableWidth * 9 / 16;
  const minimumHeight = Math.min(
    MIN_MOBILE_PLAY_AREA_HEIGHT,
    Math.max(0, Math.floor(availableHeight))
  );
  const fittedHeight = Math.floor(
    Math.max(minimumHeight, Math.min(availableHeight, aspectHeight))
  );

  playArea.style.height = `${fittedHeight}px`;
}

function loadHighScore() {
  try {
    const rawHighScore = window.localStorage.getItem(HIGH_SCORE_STORAGE_KEY);
    const parsedHighScore = Number.parseInt(rawHighScore ?? "", 10);
    return Number.isFinite(parsedHighScore) && parsedHighScore > 0 ? parsedHighScore : 0;
  } catch (error) {
    console.warn("Unable to load saved high score.", error);
    return 0;
  }
}

function saveHighScore(score) {
  try {
    window.localStorage.setItem(HIGH_SCORE_STORAGE_KEY, String(score));
  } catch (error) {
    console.warn("Unable to save high score.", error);
  }
}

function syncHighScore(distance = state.distance) {
  const score = Math.max(0, Math.floor(distance));
  if (score <= state.highScore) {
    return false;
  }

  state.highScore = score;
  saveHighScore(score);
  return true;
}

async function loadDeliveryOptions() {
  try {
    const response = await fetch(deliveryOptionsPath, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to load delivery options: ${response.status}`);
    }

    const data = await response.json();
    if (!Array.isArray(data)) {
      throw new Error("Delivery options JSON must be an array.");
    }

    const configuredOptions = data.filter(
      (item) => typeof item === "string" && item.trim().length > 0
    );

    if (configuredOptions.length > 0) {
      deliveryOptions = configuredOptions;
      return;
    }
  } catch (error) {
    console.warn(
      "Using fallback delivery options. Serve the project over HTTP to load assets/delivery-options.json reliably.",
      error
    );
  }

  deliveryOptions = [...defaultDeliveryOptions];
}

async function loadOutageReasons() {
  try {
    const response = await fetch(outageReasonsPath, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to load outage reasons: ${response.status}`);
    }

    const data = await response.json();
    if (!Array.isArray(data)) {
      throw new Error("Outage reasons JSON must be an array.");
    }

    const configuredReasons = data.filter(
      (item) => typeof item === "string" && item.trim().length > 0
    );

    if (configuredReasons.length > 0) {
      outageReasons = configuredReasons;
      return;
    }
  } catch (error) {
    console.warn(
      "Using fallback outage reasons. Serve the project over HTTP to load assets/outage-reasons.json reliably.",
      error
    );
  }

  outageReasons = [...defaultOutageReasons];
}

async function loadClientFeedbackOptions() {
  try {
    const response = await fetch(clientFeedbackPath, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to load client feedback: ${response.status}`);
    }

    const data = await response.json();
    if (!Array.isArray(data)) {
      throw new Error("Client feedback JSON must be an array.");
    }

    const configuredFeedback = data.filter(
      (item) => typeof item === "string" && item.trim().length > 0
    );

    if (configuredFeedback.length > 0) {
      clientFeedbackOptions = configuredFeedback;
      return;
    }
  } catch (error) {
    console.warn(
      "Using fallback client feedback. Serve the project over HTTP to load assets/client-feedback.json reliably.",
      error
    );
  }

  clientFeedbackOptions = [...defaultClientFeedbackOptions];
}

function spawnColumn() {
  state.columns.push(createGeneratedColumn(state.nextWorldColumnIndex));
  state.nextWorldColumnIndex += 1;
}

function startGame() {
  if (state.phase === "running") {
    return;
  }

  if (state.phase === "won" || state.phase === "lost") {
    resetGame();
  }

  state.phase = "running";
  state.lastTime = 0;
  setOverlay({ hidden: true, kicker: "", title: "", text: "", button: "" });
}

function jump() {
  if (state.phase === "idle") {
    startGame();
  }

  if (state.phase !== "running" || !state.player.grounded) {
    return;
  }

  state.player.velocityY = JUMP_VELOCITY;
  state.player.grounded = false;
}

function getDefeatConfig(cause) {
  return defeatConfigs[cause] || defeatConfigs.generic;
}

function isPlayerImmune(now = performance.now()) {
  return now < state.player.immunityUntil;
}

function getImmunityTimeRemaining(now = performance.now()) {
  return Math.max(0, state.player.immunityUntil - now);
}

function grantPlayerImmunity(now = performance.now()) {
  state.player.immunityUntil = Math.max(now, state.player.immunityUntil) + PLAYER_IMMUNITY_DURATION_MS;
}

function isDeathInputLocked(now = performance.now()) {
  return (
    state.phase === "lost" &&
    state.player.deathStartedAt !== null &&
    now - state.player.deathStartedAt < PLAYER_DEATH_INPUT_LOCK_MS
  );
}

function syncActionButtonState(now = performance.now()) {
  actionButton.disabled = isDeathInputLocked(now);
}

function failGame(cause = "generic") {
  const defeat = getDefeatConfig(cause);
  state.phase = "lost";
  state.player.deathStartedAt = performance.now();
  syncHighScore();
  updateHud();
  setOverlay({
    hidden: false,
    kicker: defeat.kicker,
    title: defeat.title,
    text: `${defeat.summary}. You migrated ${Math.floor(state.distance).toLocaleString("en-US")} clients. Best run: ${state.highScore.toLocaleString("en-US")}. Try again and push toward 19,500.`,
    button: "Restart",
  });
}

function winGame() {
  state.phase = "won";
  state.distance = TARGET_DISTANCE;
  syncHighScore(TARGET_DISTANCE);
  updateHud();
  setOverlay({
    hidden: false,
    kicker: "Target reached",
    title: "Migration milestone completed",
    text: `All 19,500 clients have made it to the new IB George Business. Best run: ${state.highScore.toLocaleString("en-US")}. Run it again to improve your timing.`,
    button: "Play again",
  });
}

function updateHud() {
  const distance = Math.floor(state.distance);
  const progress = Math.min((distance / TARGET_DISTANCE) * 100, 100);
  distanceValue.textContent = `${distance.toLocaleString("en-US")} / ${TARGET_DISTANCE.toLocaleString("en-US")}`;
  progressValue.textContent = `${progress.toFixed(progress >= 100 ? 0 : 1)}%`;
  highScoreValue.textContent = state.highScore.toLocaleString("en-US");
}

function update(delta) {
  if (state.phase !== "running") {
    return;
  }

  state.speed = Math.min(MAX_SPEED, START_SPEED + state.distance / SPEED_RAMP);
  state.distance += state.speed * delta * CLIENTS_PER_PIXEL;
  syncHighScore();
  updateHud();

  state.player.previousY = state.player.y;
  state.player.velocityY += GRAVITY * delta;
  state.player.y += state.player.velocityY * delta;

  if (state.player.y >= playerBaseY()) {
    state.player.y = playerBaseY();
    state.player.velocityY = 0;
    state.player.grounded = true;
  }

  state.offsetX += state.speed * delta;
  state.worldScroll += state.speed * delta;

  while (state.offsetX >= TILE_SIZE) {
    state.offsetX -= TILE_SIZE;
    state.worldColumnOffset += 1;
    state.columns.shift();
    spawnColumn();
  }

  updateGoodClouds(delta);
  updateBugs(delta);
  const outageEvent = updateOutages(delta);
  if (outageEvent.type === "fail") {
    failGame(outageEvent.cause);
    return;
  }

  const collision = detectCollision();
  if (collision.type === "stomp") {
    stompBug(collision.bug, collision.rect);
  } else if (collision.type === "fail") {
    failGame(collision.cause);
  } else if (state.distance >= TARGET_DISTANCE) {
    winGame();
  }
}

function detectCollision() {
  const playerLeft = state.player.x + state.player.width * 0.14;
  const playerRight = state.player.x + state.player.width * 0.86;
  const playerTop = state.player.y + state.player.height * 0.1;
  const playerBottom = state.player.y + state.player.height;
  const previousBottom = state.player.previousY + state.player.height;
  const playerCenterX = (playerLeft + playerRight) / 2;
  const playerAirborne =
    !state.player.grounded || state.player.y < playerBaseY() - STOMP_AIRBORNE_BUFFER;
  const playerImmune = isPlayerImmune();

  for (const bug of state.bugs) {
    if (bug.state !== "alive") {
      continue;
    }

    const rect = getBugRect(bug);
    if (rect.x + rect.width < 0 || rect.x > canvas.width) {
      continue;
    }

    if (
      playerRight > rect.x &&
      playerLeft < rect.x + rect.width &&
      playerBottom > rect.y &&
      playerTop < rect.y + rect.height
    ) {
      const stompedFromAbove =
        playerAirborne &&
        state.player.velocityY >= STOMP_DESCENT_ALLOWANCE &&
        previousBottom <= rect.y + STOMP_APPROACH_HEIGHT &&
        playerBottom >= rect.y &&
        playerBottom <= rect.y + STOMP_VERTICAL_OVERLAP_LIMIT &&
        playerCenterX > rect.x - STOMP_HORIZONTAL_TOLERANCE &&
        playerCenterX < rect.x + rect.width + STOMP_HORIZONTAL_TOLERANCE;

      if (stompedFromAbove) {
        return {
          type: "stomp",
          bug,
          rect,
        };
      }

      if (playerImmune) {
        continue;
      }

      return {
        type: "fail",
        cause: "bug",
      };
    }
  }

  for (let col = 0; col < state.columns.length; col += 1) {
    const column = state.columns[col];
    for (let row = 0; row < column.length; row += 1) {
      if (getCellType(column[row]) !== "obstacle") {
        continue;
      }

      const tile = getTileRect(col, row);
      const tileLeft = tile.x + TILE_SIZE * 0.15;
      const tileRight = tile.x + TILE_SIZE * 0.85;
      const tileTop = tile.y + TILE_SIZE * 0.08;
      const tileBottom = tile.y + TILE_SIZE * 0.96;

      if (
        playerRight > tileLeft &&
        playerLeft < tileRight &&
        playerBottom > tileTop &&
        playerTop < tileBottom
      ) {
        if (playerImmune) {
          continue;
        }

        return {
          type: "fail",
          cause: "blocker",
        };
      }
    }
  }

  return { type: "none" };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function getBugHeight(bug) {
  return bug.state === "dead" ? DEAD_BUG_HEIGHT : BUG_HEIGHT;
}

function getBugRect(bug) {
  const height = getBugHeight(bug);
  return {
    x: bug.worldX - state.worldScroll,
    y: groundSurfaceY() - height,
    width: BUG_WIDTH,
    height,
  };
}

function getPlayerWorldCenterX() {
  return state.worldScroll + state.player.x + state.player.width / 2;
}

function getGoodCloudRect(goodCloud, now = performance.now()) {
  return {
    x: goodCloud.worldX - state.worldScroll,
    y: goodCloud.y + Math.sin(now / 320 + goodCloud.bobPhase) * 4.5,
    width: GOOD_CLOUD_WIDTH,
    height: GOOD_CLOUD_HEIGHT,
  };
}

function cleanupGoodClouds() {
  state.goodClouds = state.goodClouds.filter(
    (goodCloud) => goodCloud.worldX + GOOD_CLOUD_WIDTH > state.worldScroll - GOOD_CLOUD_WIDTH
  );
}

function updateGoodClouds(delta) {
  maybeSpawnGoodCloud(delta);
  const now = performance.now();
  const playerLeft = state.player.x + state.player.width * 0.16;
  const playerRight = state.player.x + state.player.width * 0.84;
  const playerTop = state.player.y + state.player.height * 0.08;
  const playerBottom = state.player.y + state.player.height * 0.94;

  state.goodClouds = state.goodClouds.filter((goodCloud) => {
    const rect = getGoodCloudRect(goodCloud, now);
    const pickedUp =
      playerRight > rect.x + GOOD_CLOUD_COLLISION_PADDING_X &&
      playerLeft < rect.x + rect.width - GOOD_CLOUD_COLLISION_PADDING_X &&
      playerBottom > rect.y + GOOD_CLOUD_COLLISION_PADDING_Y &&
      playerTop < rect.y + rect.height - GOOD_CLOUD_COLLISION_PADDING_Y;

    if (pickedUp) {
      grantPlayerImmunity(now);
      return false;
    }

    return goodCloud.worldX + GOOD_CLOUD_WIDTH > state.worldScroll - GOOD_CLOUD_WIDTH;
  });

  cleanupGoodClouds();
}

function isPlayerInFireballImpactZone(fireball) {
  const playerBottom = state.player.y + state.player.height;
  return (
    Math.abs(getPlayerWorldCenterX() - fireball.worldX) <= FIREBALL_IMPACT_RADIUS &&
    playerBottom >= groundSurfaceY() - FIREBALL_IMPACT_GROUND_CLEARANCE
  );
}

function spawnFireball(outage, progress) {
  const horizontalPadding = OUTAGE_WIDTH * 0.2;
  state.fireballs.push({
    worldX: outage.worldX + randomFloat(horizontalPadding, OUTAGE_WIDTH - horizontalPadding),
    y: outage.y + OUTAGE_HEIGHT * 0.56,
    velocityY: randomFloat(
      FIREBALL_FALL_SPEED_MIN,
      FIREBALL_FALL_SPEED_MAX + progress * 70
    ),
    rotation: randomFloat(-0.14, 0.14),
    spin: randomFloat(-3.2, 3.2),
    reason: randomItem(outageReasons),
    state: "falling",
    impactedAt: null,
  });
}

function cleanupOutages(now) {
  state.outages = state.outages.filter(
    (outage) => outage.worldX + OUTAGE_WIDTH > state.worldScroll - OUTAGE_WIDTH
  );
  state.fireballs = state.fireballs.filter((fireball) => {
    if (fireball.state === "falling") {
      return fireball.y < canvas.height + FIREBALL_HEIGHT;
    }

    return now - fireball.impactedAt < FIREBALL_IMPACT_EFFECT_MS;
  });
}

function updateOutages(delta) {
  maybeSpawnOutage(delta);
  const progress = getProgressRatio();

  for (const outage of state.outages) {
    const screenX = outage.worldX - state.worldScroll;
    const isOnScreen = screenX < canvas.width + OUTAGE_WIDTH * 0.35 && screenX + OUTAGE_WIDTH > 0;

    if (!isOnScreen || outage.remainingDrops <= 0) {
      continue;
    }

    outage.nextDropIn -= delta;
    if (outage.nextDropIn <= 0) {
      spawnFireball(outage, progress);
      outage.remainingDrops -= 1;
      outage.nextDropIn = getOutageDropInterval(progress);
    }
  }

  const now = performance.now();
  for (const fireball of state.fireballs) {
    if (fireball.state !== "falling") {
      continue;
    }

    fireball.y += fireball.velocityY * delta;
    fireball.rotation += fireball.spin * delta;

    if (fireball.y + FIREBALL_HEIGHT >= groundSurfaceY()) {
      fireball.y = groundSurfaceY() - FIREBALL_HEIGHT;
      fireball.state = "impact";
      fireball.impactedAt = now;

      if (isPlayerInFireballImpactZone(fireball) && !isPlayerImmune(now)) {
        cleanupOutages(now);
        return {
          type: "fail",
          cause: "outage",
        };
      }
    }
  }

  cleanupOutages(now);
  return { type: "none" };
}

function cleanupBugs() {
  state.bugs = state.bugs.filter(
    (bug) => bug.patrolEnd + BUG_WIDTH > state.worldScroll - TILE_SIZE * 2
  );
}

function updateBugs(delta) {
  for (const bug of state.bugs) {
    if (bug.state !== "alive") {
      continue;
    }

    bug.worldX += bug.direction * bug.speed * delta;

    if (bug.worldX <= bug.patrolStart) {
      bug.worldX = bug.patrolStart;
      bug.direction = 1;
    } else if (bug.worldX >= bug.patrolEnd) {
      bug.worldX = bug.patrolEnd;
      bug.direction = -1;
    }
  }

  cleanupBugs();
}

function stompBug(bug, rect) {
  bug.state = "dead";
  bug.speed = 0;
  bug.direction = 0;
  state.player.y = rect.y - state.player.height + 2;
  state.player.velocityY = STOMP_BOUNCE_VELOCITY;
  state.player.grounded = false;
}

function drawBackdropBase() {
  const skyImage = supportImages.sky;
  if (skyImage.complete && skyImage.naturalWidth > 0) {
    ctx.drawImage(skyImage, 0, 0, canvas.width, canvas.height);
    return;
  }

  const skyGradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  skyGradient.addColorStop(0, "#dcecff");
  skyGradient.addColorStop(0.55, "#f5eddc");
  skyGradient.addColorStop(1, "#dfedd6");
  ctx.fillStyle = skyGradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.fillStyle = "rgba(255,255,255,0.4)";
  ctx.beginPath();
  ctx.ellipse(canvas.width * 0.2, canvas.height * 0.18, 110, 42, 0, 0, Math.PI * 2);
  ctx.ellipse(canvas.width * 0.72, canvas.height * 0.13, 150, 54, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawRepeatingBackgroundLayer(layer) {
  const image = layer.image;
  const drawHeight = layer.height;
  const bottomGap = Math.max(0, (layer.bottomGap ?? 0) - BASE_PARALLAX_BOTTOM_GAP) * PARALLAX_GAP_SCALE;
  const drawY = groundSurfaceY() - bottomGap - drawHeight;

  if (!(image.complete && image.naturalWidth > 0)) {
    ctx.fillStyle = layer.fallback;
    ctx.fillRect(0, drawY + drawHeight * 0.45, canvas.width, drawHeight * 0.55);
    return;
  }

  const scale = drawHeight / image.naturalHeight;
  const drawWidth = image.naturalWidth * scale;
  const offset = (state.worldScroll * layer.speed) % drawWidth;

  for (
    let drawX = -offset - drawWidth;
    drawX < canvas.width + drawWidth;
    drawX += drawWidth
  ) {
    ctx.drawImage(image, drawX, drawY, drawWidth, drawHeight);
  }
}

function drawParallaxLayers() {
  for (const layer of backgroundLayers) {
    drawRepeatingBackgroundLayer(layer);
  }
}

function drawForegroundBackdropLayer() {
  const backdropBaseY = groundSurfaceY();
  ctx.fillStyle = "rgba(15, 118, 110, 0.08)";
  ctx.beginPath();
  ctx.moveTo(0, backdropBaseY);
  ctx.quadraticCurveTo(canvas.width * 0.18, backdropBaseY - 78, canvas.width * 0.4, backdropBaseY - 22);
  ctx.quadraticCurveTo(canvas.width * 0.68, backdropBaseY - 14, canvas.width, backdropBaseY - 58);
  ctx.lineTo(canvas.width, backdropBaseY);
  ctx.lineTo(0, backdropBaseY);
  ctx.closePath();
  ctx.fill();
}

function drawBackdrop() {
  drawBackdropBase();
  drawGroundTransition();
  drawParallaxLayers();
  drawForegroundBackdropLayer();
}

function drawOutageClouds() {
  const now = performance.now();

  for (const outage of state.outages) {
    const drawX = outage.worldX - state.worldScroll;
    if (drawX + OUTAGE_WIDTH < -OUTAGE_WIDTH || drawX > canvas.width + OUTAGE_WIDTH) {
      continue;
    }

    const bobOffset = Math.sin(now / 260 + outage.bobPhase) * 3.5;
    const drawY = outage.y + bobOffset;

    if (outageImages.cloud.complete && outageImages.cloud.naturalWidth > 0) {
      ctx.drawImage(outageImages.cloud, drawX, drawY, OUTAGE_WIDTH, OUTAGE_HEIGHT);
    } else {
      ctx.fillStyle = "#564f58";
      ctx.beginPath();
      ctx.ellipse(
        drawX + OUTAGE_WIDTH * 0.5,
        drawY + OUTAGE_HEIGHT * 0.45,
        OUTAGE_WIDTH * 0.42,
        OUTAGE_HEIGHT * 0.32,
        0,
        0,
        Math.PI * 2
      );
      ctx.fill();
    }
  }
}

function drawGoodClouds() {
  const now = performance.now();

  for (const goodCloud of state.goodClouds) {
    const rect = getGoodCloudRect(goodCloud, now);
    if (rect.x + rect.width < -rect.width || rect.x > canvas.width + rect.width) {
      continue;
    }

    if (supportImages.goodCloud.complete && supportImages.goodCloud.naturalWidth > 0) {
      ctx.drawImage(supportImages.goodCloud, rect.x, rect.y, rect.width, rect.height);
    } else {
      ctx.fillStyle = "#bdf6fa";
      ctx.beginPath();
      ctx.ellipse(
        rect.x + rect.width * 0.5,
        rect.y + rect.height * 0.46,
        rect.width * 0.42,
        rect.height * 0.3,
        0,
        0,
        Math.PI * 2
      );
      ctx.fill();
    }
  }
}

function drawGroundTransition() {
  const drawY = backgroundStartY() - GROUND_TRANSITION_OVERLAP;
  const drawHeight = groundSurfaceY() - drawY;
  const transitionOverlay = supportImages.groundTransition;

  if (!(transitionOverlay.complete && transitionOverlay.naturalWidth > 0)) {
    const fallbackGradient = ctx.createLinearGradient(0, drawY, 0, drawY + drawHeight);
    fallbackGradient.addColorStop(0, "rgba(144, 170, 111, 0.96)");
    fallbackGradient.addColorStop(0.55, "rgba(112, 142, 82, 0.98)");
    fallbackGradient.addColorStop(1, "rgba(85, 111, 63, 1)");
    ctx.fillStyle = fallbackGradient;
    ctx.fillRect(0, drawY, canvas.width, drawHeight);
    return;
  }

  const scale = drawHeight / transitionOverlay.naturalHeight;
  const drawWidth = transitionOverlay.naturalWidth * scale;
  const offset = state.worldScroll % drawWidth;

  for (
    let drawX = -offset - drawWidth;
    drawX < canvas.width + drawWidth;
    drawX += drawWidth
  ) {
    ctx.drawImage(transitionOverlay, drawX, drawY, drawWidth, drawHeight);
  }
}

function drawTiles() {
  for (let col = 0; col < state.columns.length; col += 1) {
    const column = state.columns[col];
    for (let row = 0; row < column.length; row += 1) {
      const tileType = getCellType(column[row]);
      if (!tileType) {
        continue;
      }

      const tile = getTileRect(col, row);
      const image = tileImages[tileType];
      const isGroundTile = tileType === "floorTop" || tileType === "floorBase";
      const drawWidth = isGroundTile ? TILE_SIZE + 1 : TILE_SIZE;
      const drawHeight = isGroundTile ? TILE_SIZE + 1 : TILE_SIZE;
      if (image.complete && image.naturalWidth > 0) {
        ctx.drawImage(image, tile.x, tile.y, drawWidth, drawHeight);
      } else {
        ctx.fillStyle =
          tileType === "obstacle"
            ? "#8d3b2f"
            : tileType === "floorTop"
              ? "#7ca95d"
              : "#587447";
        ctx.fillRect(tile.x, tile.y, drawWidth, drawHeight);
      }
    }
  }
}

function drawFireballs() {
  const now = performance.now();

  for (const fireball of state.fireballs) {
    const drawX = fireball.worldX - state.worldScroll - FIREBALL_WIDTH / 2;
    if (drawX + FIREBALL_WIDTH < -48 || drawX > canvas.width + 48) {
      continue;
    }

    if (fireball.state === "impact") {
      const impactAge = Math.min(
        1,
        (now - fireball.impactedAt) / FIREBALL_IMPACT_EFFECT_MS
      );
      const centerX = fireball.worldX - state.worldScroll;
      const outerRadius = FIREBALL_IMPACT_RADIUS * (0.42 + impactAge * 0.58);
      const innerRadius = outerRadius * 0.55;

      ctx.fillStyle = `rgba(241, 138, 58, ${0.42 * (1 - impactAge)})`;
      ctx.beginPath();
      ctx.ellipse(centerX, groundSurfaceY() + 5, outerRadius, TILE_SIZE * 0.18, 0, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = `rgba(255, 227, 139, ${0.58 * (1 - impactAge)})`;
      ctx.beginPath();
      ctx.ellipse(centerX, groundSurfaceY() + 4, innerRadius, TILE_SIZE * 0.11, 0, 0, Math.PI * 2);
      ctx.fill();
      continue;
    }

    if (outageImages.fireball.complete && outageImages.fireball.naturalWidth > 0) {
      const frameIndex =
        Math.floor((now + fireball.worldX) / FIREBALL_FRAME_MS) % FIREBALL_FRAMES;
      ctx.save();
      ctx.translate(
        drawX + FIREBALL_WIDTH / 2,
        fireball.y + FIREBALL_HEIGHT / 2
      );
      ctx.rotate(fireball.rotation);
      ctx.drawImage(
        outageImages.fireball,
        frameIndex * FIREBALL_FRAME_WIDTH,
        0,
        FIREBALL_FRAME_WIDTH,
        FIREBALL_FRAME_HEIGHT,
        -FIREBALL_WIDTH / 2,
        -FIREBALL_HEIGHT / 2,
        FIREBALL_WIDTH,
        FIREBALL_HEIGHT
      );
      ctx.restore();
    } else {
      ctx.fillStyle = "#e97a2f";
      ctx.beginPath();
      ctx.ellipse(
        drawX + FIREBALL_WIDTH / 2,
        fireball.y + FIREBALL_HEIGHT / 2,
        FIREBALL_WIDTH * 0.34,
        FIREBALL_HEIGHT * 0.45,
        fireball.rotation,
        0,
        Math.PI * 2
      );
      ctx.fill();
    }
  }
}

function drawBugs() {
  for (const bug of state.bugs) {
    const rect = getBugRect(bug);
    if (rect.x + rect.width < -24 || rect.x > canvas.width + 24) {
      continue;
    }

    const image = bug.state === "dead" ? bugImages.dead : bugImages.alive;
    const bobOffset =
      bug.state === "alive"
        ? Math.sin(performance.now() / 130 + bug.worldX / 45) * 1.5
        : 0;

    if (image.complete && image.naturalWidth > 0) {
      ctx.save();
      const frameIndex =
        bug.state === "alive"
          ? Math.floor((performance.now() + bug.worldX * 5) / BUG_ANIMATION_SPEED_MS) %
            BUG_ANIMATION_FRAMES
          : 0;
      if (bug.state === "alive" && bug.direction < 0) {
        ctx.translate(rect.x + rect.width / 2, rect.y + rect.height / 2 + bobOffset);
        ctx.scale(-1, 1);
        ctx.drawImage(
          image,
          frameIndex * BUG_ANIMATION_FRAME_WIDTH,
          0,
          BUG_ANIMATION_FRAME_WIDTH,
          BUG_ANIMATION_FRAME_HEIGHT,
          -rect.width / 2,
          -rect.height / 2,
          rect.width,
          rect.height
        );
      } else if (bug.state === "alive") {
        ctx.drawImage(
          image,
          frameIndex * BUG_ANIMATION_FRAME_WIDTH,
          0,
          BUG_ANIMATION_FRAME_WIDTH,
          BUG_ANIMATION_FRAME_HEIGHT,
          rect.x,
          rect.y + bobOffset,
          rect.width,
          rect.height
        );
      } else {
        ctx.drawImage(image, rect.x, rect.y + bobOffset, rect.width, rect.height);
      }
      ctx.restore();
    } else {
      ctx.fillStyle = bug.state === "alive" ? "#7b4621" : "#8d7047";
      ctx.fillRect(rect.x, rect.y + bobOffset, rect.width, rect.height);
    }
  }
}

function fitBubbleLines(text, maxWidth, maxLines) {
  const words = text.trim().split(/\s+/).filter(Boolean);
  const lines = [];
  let currentLine = "";

  function trimToWidth(value, suffix = "") {
    let candidate = value;
    while (candidate && ctx.measureText(candidate + suffix).width > maxWidth) {
      candidate = candidate.slice(0, -1);
    }
    return candidate + suffix;
  }

  for (const word of words) {
    const candidate = currentLine ? `${currentLine} ${word}` : word;
    if (ctx.measureText(candidate).width <= maxWidth) {
      currentLine = candidate;
      continue;
    }

    if (currentLine) {
      lines.push(currentLine);
      currentLine = "";
      if (lines.length === maxLines) {
        break;
      }
    }

    if (ctx.measureText(word).width <= maxWidth) {
      currentLine = word;
      continue;
    }

    currentLine = trimToWidth(word, "...");
  }

  if (currentLine && lines.length < maxLines) {
    lines.push(currentLine);
  }

  if (lines.length === 0) {
    lines.push("Delivery");
  }

  if (lines.length > maxLines) {
    lines.length = maxLines;
  }

  if (words.length > 0 && lines.length === maxLines) {
    const joined = lines.join(" ");
    if (joined.replace(/\.\.\.$/, "") !== text.trim()) {
      lines[maxLines - 1] = trimToWidth(lines[maxLines - 1].replace(/\.\.\.$/, ""), "...");
    }
  }

  return lines;
}

function drawGoodCloudFeedbackBubbles() {
  ctx.save();
  const now = performance.now();
  const fontSize = 15;
  const lineHeight = 18;
  const paddingX = 16;
  const paddingY = 11;
  const maxTextWidth = 214;
  ctx.font = `700 ${fontSize}px Trebuchet MS`;
  ctx.textBaseline = "top";
  ctx.textAlign = "left";

  for (const goodCloud of state.goodClouds) {
    if (!goodCloud.feedback) {
      continue;
    }

    const rect = getGoodCloudRect(goodCloud, now);
    if (rect.x + rect.width < 0 || rect.x > canvas.width) {
      continue;
    }

    const lines = fitBubbleLines(goodCloud.feedback, maxTextWidth, 3);
    const contentWidth = lines.reduce(
      (max, line) => Math.max(max, ctx.measureText(line).width),
      100
    );
    const bubbleWidth = Math.max(144, contentWidth + paddingX * 2);
    const bubbleHeight = lines.length * lineHeight + paddingY * 2;
    const anchorX = rect.x + rect.width / 2;
    const bubbleX = clamp(anchorX - bubbleWidth / 2, 8, canvas.width - bubbleWidth - 8);
    const bubbleY = Math.max(8, rect.y - bubbleHeight - 18);
    const tailX = clamp(anchorX, bubbleX + 16, bubbleX + bubbleWidth - 16);

    ctx.fillStyle = "rgba(235, 255, 250, 0.96)";
    drawRoundedRect(bubbleX, bubbleY, bubbleWidth, bubbleHeight, 12);
    ctx.fill();

    ctx.strokeStyle = "#397170";
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = "rgba(235, 255, 250, 0.96)";
    ctx.beginPath();
    ctx.moveTo(tailX - 10, bubbleY + bubbleHeight - 2);
    ctx.lineTo(tailX + 10, bubbleY + bubbleHeight - 2);
    ctx.lineTo(tailX, bubbleY + bubbleHeight + 12);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "#397170";
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = "#23504f";
    lines.forEach((line, index) => {
      ctx.fillText(line, bubbleX + paddingX, bubbleY + paddingY + index * lineHeight);
    });
  }

  ctx.restore();
}

function drawFireballReasonBubbles() {
  ctx.save();
  const fontSize = 15;
  const lineHeight = 18;
  const paddingX = 16;
  const paddingY = 11;
  const maxTextWidth = 200;
  ctx.font = `700 ${fontSize}px Trebuchet MS`;
  ctx.textBaseline = "top";
  ctx.textAlign = "left";

  for (const fireball of state.fireballs) {
    if (fireball.state !== "falling" || !fireball.reason) {
      continue;
    }

    const anchorX = fireball.worldX - state.worldScroll;
    if (anchorX + FIREBALL_WIDTH < 0 || anchorX > canvas.width) {
      continue;
    }

    const lines = fitBubbleLines(fireball.reason, maxTextWidth, 3);
    const contentWidth = lines.reduce(
      (max, line) => Math.max(max, ctx.measureText(line).width),
      92
    );
    const bubbleWidth = Math.max(136, contentWidth + paddingX * 2);
    const bubbleHeight = lines.length * lineHeight + paddingY * 2;
    const bubbleX = clamp(anchorX - bubbleWidth / 2, 8, canvas.width - bubbleWidth - 8);
    const bubbleY = Math.max(8, fireball.y - bubbleHeight - 28);
    const tailX = clamp(anchorX, bubbleX + 16, bubbleX + bubbleWidth - 16);

    ctx.fillStyle = "rgba(255, 245, 232, 0.96)";
    drawRoundedRect(bubbleX, bubbleY, bubbleWidth, bubbleHeight, 12);
    ctx.fill();

    ctx.strokeStyle = "#5d4330";
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = "rgba(255, 245, 232, 0.96)";
    ctx.beginPath();
    ctx.moveTo(tailX - 10, bubbleY + bubbleHeight - 2);
    ctx.lineTo(tailX + 10, bubbleY + bubbleHeight - 2);
    ctx.lineTo(tailX, bubbleY + bubbleHeight + 12);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = "#5d4330";
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.fillStyle = "#372619";
    lines.forEach((line, index) => {
      ctx.fillText(line, bubbleX + paddingX, bubbleY + paddingY + index * lineHeight);
    });
  }

  ctx.restore();
}

function drawObstacleBubbles() {
  ctx.save();
  const fontSize = 20;
  const lineHeight = 22;
  const paddingX = 22;
  const paddingY = 14;
  const maxTextWidth = 252;
  ctx.font = `700 ${fontSize}px Trebuchet MS`;
  ctx.textBaseline = "top";
  ctx.textAlign = "left";

  for (let col = 0; col < state.columns.length; col += 1) {
    const column = state.columns[col];
    for (let row = 0; row < column.length; row += 1) {
      const cell = column[row];
      if (getCellType(cell) !== "obstacle") {
        continue;
      }

      const tile = getTileRect(col, row);
      if (tile.x + tile.width < 0 || tile.x > canvas.width) {
        continue;
      }

      const lines = fitBubbleLines(cell.label || "Delivery", maxTextWidth, 3);
      const contentWidth = lines.reduce(
        (max, line) => Math.max(max, ctx.measureText(line).width),
        116
      );
      const bubbleWidth = Math.max(152, contentWidth + paddingX * 2);
      const bubbleHeight = lines.length * lineHeight + paddingY * 2;
      const anchorX = tile.x + tile.width / 2;
      const bubbleX = clamp(
        anchorX - bubbleWidth / 2,
        8,
        canvas.width - bubbleWidth - 8
      );
      const bubbleY = Math.max(8, tile.y - bubbleHeight - 18);
      const tailX = clamp(anchorX, bubbleX + 18, bubbleX + bubbleWidth - 18);

      ctx.fillStyle = "rgba(255, 251, 243, 0.96)";
      drawRoundedRect(bubbleX, bubbleY, bubbleWidth, bubbleHeight, 12);
      ctx.fill();

      ctx.strokeStyle = "#4c443a";
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.fillStyle = "rgba(255, 251, 243, 0.96)";
      ctx.beginPath();
      ctx.moveTo(tailX - 12, bubbleY + bubbleHeight - 2);
      ctx.lineTo(tailX + 12, bubbleY + bubbleHeight - 2);
      ctx.lineTo(tailX, bubbleY + bubbleHeight + 16);
      ctx.closePath();
      ctx.fill();

      ctx.strokeStyle = "#4c443a";
      ctx.lineWidth = 2;
      ctx.stroke();

      ctx.fillStyle = "#2b241d";
      lines.forEach((line, index) => {
        ctx.fillText(line, bubbleX + paddingX, bubbleY + paddingY + index * lineHeight);
      });
    }
  }

  ctx.restore();
}

function drawPlayer() {
  const { x, y, width, height, grounded, velocityY } = state.player;
  const immune = isPlayerImmune();
  const now = performance.now();

  ctx.fillStyle = "rgba(0, 0, 0, 0.14)";
  ctx.beginPath();
  ctx.ellipse(x + width / 2, groundSurfaceY() + 8, width * 0.36, 10, 0, 0, Math.PI * 2);
  ctx.fill();

  const drawWidth = TILE_SIZE * 1.55;
  const drawHeight = TILE_SIZE * 1.55;
  const drawX = x - TILE_SIZE * 0.36;
  const drawY = y - TILE_SIZE * 0.24;

  if (immune) {
    const pulse = 0.84 + (Math.sin(now / 120) + 1) * 0.08;
    ctx.save();
    ctx.fillStyle = "rgba(149, 245, 237, 0.2)";
    ctx.beginPath();
    ctx.ellipse(
      drawX + drawWidth / 2,
      drawY + drawHeight / 2,
      drawWidth * 0.44 * pulse,
      drawHeight * 0.48 * pulse,
      0,
      0,
      Math.PI * 2
    );
    ctx.fill();

    ctx.strokeStyle = "rgba(81, 201, 193, 0.9)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.ellipse(
      drawX + drawWidth / 2,
      drawY + drawHeight / 2,
      drawWidth * 0.38 * pulse,
      drawHeight * 0.43 * pulse,
      0,
      0,
      Math.PI * 2
    );
    ctx.stroke();
    ctx.restore();
  }

  if (state.phase === "lost" && state.player.deathStartedAt !== null) {
    const deathFrameIndex = Math.min(
      PLAYER_DEATH_FRAMES - 1,
      Math.floor((now - state.player.deathStartedAt) / PLAYER_DEATH_FRAME_MS)
    );

    if (playerDeathSprite.complete && playerDeathSprite.naturalWidth > 0) {
      ctx.drawImage(
        playerDeathSprite,
        deathFrameIndex * PLAYER_DEATH_FRAME_WIDTH,
        0,
        PLAYER_DEATH_FRAME_WIDTH,
        PLAYER_DEATH_FRAME_HEIGHT,
        drawX,
        drawY,
        drawWidth,
        drawHeight
      );
      return;
    }
  }

  const runFrame = playerFrames.run[Math.floor(now / 110) % playerFrames.run.length];
  const frameIndex = grounded ? runFrame : playerFrames.jump;

  if (playerSprite.complete && playerSprite.naturalWidth > 0) {
    ctx.save();
    ctx.translate(drawX + drawWidth / 2, drawY + drawHeight / 2);
    ctx.rotate(grounded ? 0 : Math.max(-0.08, Math.min(0.08, velocityY / 2500)));
    ctx.drawImage(
      playerSprite,
      frameIndex * spriteFrameWidth,
      0,
      spriteFrameWidth,
      spriteFrameHeight,
      -drawWidth / 2,
      -drawHeight / 2,
      drawWidth,
      drawHeight
    );
    ctx.restore();
    return;
  }

  ctx.fillStyle = "#124f49";
  drawRoundedRect(drawX + width * 0.06, drawY + height * 0.2, width * 0.88, height * 0.8, 14);
  ctx.fill();
}

function drawImmunityStatus() {
  const remainingMs = getImmunityTimeRemaining();
  if (remainingMs <= 0) {
    return;
  }

  ctx.save();
  const seconds = (remainingMs / 1000).toFixed(1);
  const badgeX = 24;
  const badgeY = 24;
  const badgeWidth = 170;
  const badgeHeight = 38;

  ctx.fillStyle = "rgba(236, 255, 251, 0.94)";
  drawRoundedRect(badgeX, badgeY, badgeWidth, badgeHeight, 999);
  ctx.fill();

  ctx.strokeStyle = "#3b8f8d";
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = "#1f5d5a";
  ctx.font = "700 16px Trebuchet MS";
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.fillText(`Immunity ${seconds}s`, badgeX + 16, badgeY + badgeHeight / 2 + 1);
  ctx.restore();
}

function drawGoalMarker() {
  ctx.save();
  const remaining = Math.max(0, TARGET_DISTANCE - state.distance);
  const markerRatio = Math.min(1, state.distance / TARGET_DISTANCE);
  const barWidth = canvas.width * 0.24;
  const barX = canvas.width - barWidth - 28;
  const barY = 24;

  ctx.fillStyle = "rgba(255,255,255,0.72)";
  drawRoundedRect(barX, barY, barWidth, 18, 999);
  ctx.fill();

  ctx.fillStyle = "#0f766e";
  drawRoundedRect(barX, barY, barWidth * markerRatio, 18, 999);
  ctx.fill();

  ctx.fillStyle = "#19413b";
  ctx.font = "600 14px Trebuchet MS";
  ctx.textAlign = "right";
  ctx.fillText(
    remaining > 0
      ? `${Math.ceil(remaining).toLocaleString("en-US")} to goal`
      : "Target complete",
    barX + barWidth,
    barY + 36
  );
  ctx.restore();
}

function draw() {
  ctx.imageSmoothingEnabled = false;
  drawBackdrop();
  drawOutageClouds();
  drawGoodClouds();
  drawTiles();
  drawBugs();
  drawFireballs();
  drawGoodCloudFeedbackBubbles();
  drawFireballReasonBubbles();
  drawObstacleBubbles();
  drawPlayer();
  drawImmunityStatus();
  drawGoalMarker();
}

function loop(timestamp) {
  if (!state.lastTime) {
    state.lastTime = timestamp;
  }

  const delta = Math.min((timestamp - state.lastTime) / 1000, 0.05);
  state.lastTime = timestamp;

  update(delta);
  syncActionButtonState(timestamp);
  draw();
  requestAnimationFrame(loop);
}

function handlePrimaryAction(event) {
  if (event.type === "keydown" && event.code !== "Space") {
    return;
  }

  if (event.cancelable) {
    event.preventDefault();
  }

  if (isDeathInputLocked()) {
    return;
  }

  if (state.phase === "lost" || state.phase === "won") {
    startGame();
    return;
  }

  if (state.phase === "idle") {
    jump();
    return;
  }

  jump();
}

window.addEventListener("keydown", handlePrimaryAction);
window.addEventListener("resize", syncPlayAreaToViewport);
window.visualViewport?.addEventListener("resize", syncPlayAreaToViewport);
playArea.addEventListener("pointerdown", (event) => {
  if (event.target === actionButton) {
    return;
  }

  handlePrimaryAction(event);
});
actionButton.addEventListener("click", (event) => {
  event.preventDefault();
  if (isDeathInputLocked()) {
    return;
  }

  if (state.phase === "running") {
    jump();
    return;
  }

  startGame();
});

async function initializeGame() {
  await Promise.all([
    loadDeliveryOptions(),
    loadOutageReasons(),
    loadClientFeedbackOptions(),
  ]);
  state.highScore = loadHighScore();
  resetGame();
  syncPlayAreaToViewport();
  requestAnimationFrame(loop);
}

initializeGame();
