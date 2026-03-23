const TARGET_DISTANCE = 19500;
const TILE_SIZE = 48;
const WORLD_COLUMNS = 28;
const WORLD_ROWS = 7;
const GRAVITY = 2200;
const JUMP_VELOCITY = -760;
const MIN_OBSTACLE_GAP = 12;
const MAX_OBSTACLE_GAP = 20;
const START_SPEED = 320;
const MAX_SPEED = 560;
const SPEED_RAMP = 90;
const CLIENTS_PER_PIXEL = 0.68;

const canvas = document.getElementById("gameCanvas");
const ctx = canvas.getContext("2d");
const distanceValue = document.getElementById("distanceValue");
const progressValue = document.getElementById("progressValue");
const overlay = document.getElementById("overlay");
const overlayKicker = document.getElementById("overlayKicker");
const overlayTitle = document.getElementById("overlayTitle");
const overlayText = document.getElementById("overlayText");
const actionButton = document.getElementById("actionButton");
const playArea = document.querySelector(".play-area");

const tileImages = {
  floorTop: new Image(),
  floorBase: new Image(),
  obstacle: new Image(),
};

tileImages.floorTop.src = "assets/tile-floor-top.svg";
tileImages.floorBase.src = "assets/tile-floor-base.svg";
tileImages.obstacle.src = "assets/tile-obstacle.svg";

const playerSprite = new Image();
playerSprite.src = "assets/player-runner-sprite.svg";

const playerFrames = {
  run: [0, 1, 2],
  jump: 3,
};
const spriteFrameWidth = 64;
const spriteFrameHeight = 64;

const state = {
  phase: "idle",
  lastTime: 0,
  distance: 0,
  speed: START_SPEED,
  offsetX: 0,
  nextObstacleInTiles: 14,
  columns: [],
  player: {
    width: TILE_SIZE * 0.8,
    height: TILE_SIZE * 1.15,
    x: TILE_SIZE * 3,
    y: 0,
    velocityY: 0,
    grounded: true,
  },
};

const worldTop = () => canvas.height - WORLD_ROWS * TILE_SIZE - TILE_SIZE;
const groundRow = () => WORLD_ROWS - 2;
const groundSurfaceY = () => worldTop() + groundRow() * TILE_SIZE;
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
    x: columnIndex * TILE_SIZE - state.offsetX,
    y: worldTop() + rowIndex * TILE_SIZE,
    width: TILE_SIZE,
    height: TILE_SIZE,
  };
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

function buildInitialWorld() {
  state.columns = [];
  for (let index = 0; index < WORLD_COLUMNS + 4; index += 1) {
    const column = createEmptyColumn();
    if (index > 10 && state.nextObstacleInTiles <= 0) {
      column[groundRow() - 1] = "obstacle";
      state.nextObstacleInTiles = randomInt(MIN_OBSTACLE_GAP, MAX_OBSTACLE_GAP);
    } else {
      state.nextObstacleInTiles -= 1;
    }
    state.columns.push(column);
  }
}

function resetGame() {
  state.phase = "idle";
  state.lastTime = 0;
  state.distance = 0;
  state.speed = START_SPEED;
  state.offsetX = 0;
  state.nextObstacleInTiles = 16;
  state.player.y = playerBaseY();
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
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function spawnColumn() {
  const column = createEmptyColumn();
  if (state.nextObstacleInTiles <= 0) {
    column[groundRow() - 1] = "obstacle";
    state.nextObstacleInTiles = randomInt(MIN_OBSTACLE_GAP, MAX_OBSTACLE_GAP);
  } else {
    state.nextObstacleInTiles -= 1;
  }
  state.columns.push(column);
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

function failGame() {
  state.phase = "lost";
  setOverlay({
    hidden: false,
    kicker: "Run ended",
    title: "A blocker stopped the migration",
    text: `You migrated ${Math.floor(state.distance).toLocaleString("en-US")} clients. Try again and push toward 19,500.`,
    button: "Restart",
  });
}

function winGame() {
  state.phase = "won";
  state.distance = TARGET_DISTANCE;
  updateHud();
  setOverlay({
    hidden: false,
    kicker: "Target reached",
    title: "Migration milestone completed",
    text: "All 19,500 clients have made it to the new IB George Business. Run it again to improve your timing.",
    button: "Play again",
  });
}

function updateHud() {
  const distance = Math.floor(state.distance);
  const progress = Math.min((distance / TARGET_DISTANCE) * 100, 100);
  distanceValue.textContent = `${distance.toLocaleString("en-US")} / ${TARGET_DISTANCE.toLocaleString("en-US")}`;
  progressValue.textContent = `${progress.toFixed(progress >= 100 ? 0 : 1)}%`;
}

function update(delta) {
  if (state.phase !== "running") {
    return;
  }

  state.speed = Math.min(MAX_SPEED, START_SPEED + state.distance / SPEED_RAMP);
  state.distance += state.speed * delta * CLIENTS_PER_PIXEL;
  updateHud();

  state.player.velocityY += GRAVITY * delta;
  state.player.y += state.player.velocityY * delta;

  if (state.player.y >= playerBaseY()) {
    state.player.y = playerBaseY();
    state.player.velocityY = 0;
    state.player.grounded = true;
  }

  state.offsetX += state.speed * delta;

  while (state.offsetX >= TILE_SIZE) {
    state.offsetX -= TILE_SIZE;
    state.columns.shift();
    spawnColumn();
  }

  if (detectCollision()) {
    failGame();
  } else if (state.distance >= TARGET_DISTANCE) {
    winGame();
  }
}

function detectCollision() {
  const playerLeft = state.player.x + state.player.width * 0.14;
  const playerRight = state.player.x + state.player.width * 0.86;
  const playerTop = state.player.y + state.player.height * 0.1;
  const playerBottom = state.player.y + state.player.height;

  for (let col = 0; col < state.columns.length; col += 1) {
    const column = state.columns[col];
    for (let row = 0; row < column.length; row += 1) {
      if (column[row] !== "obstacle") {
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
        return true;
      }
    }
  }

  return false;
}

function drawBackdrop() {
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

  ctx.fillStyle = "rgba(15, 118, 110, 0.08)";
  ctx.beginPath();
  ctx.moveTo(0, canvas.height * 0.84);
  ctx.quadraticCurveTo(canvas.width * 0.18, canvas.height * 0.68, canvas.width * 0.4, canvas.height * 0.8);
  ctx.quadraticCurveTo(canvas.width * 0.68, canvas.height * 0.95, canvas.width, canvas.height * 0.72);
  ctx.lineTo(canvas.width, canvas.height);
  ctx.lineTo(0, canvas.height);
  ctx.closePath();
  ctx.fill();
}

function drawTiles() {
  for (let col = 0; col < state.columns.length; col += 1) {
    const column = state.columns[col];
    for (let row = 0; row < column.length; row += 1) {
      const tileType = column[row];
      if (!tileType) {
        continue;
      }

      const tile = getTileRect(col, row);
      const image = tileImages[tileType];
      if (image.complete && image.naturalWidth > 0) {
        ctx.drawImage(image, tile.x, tile.y, TILE_SIZE, TILE_SIZE);
      } else {
        ctx.fillStyle =
          tileType === "obstacle"
            ? "#8d3b2f"
            : tileType === "floorTop"
              ? "#7ca95d"
              : "#587447";
        ctx.fillRect(tile.x, tile.y, TILE_SIZE, TILE_SIZE);
      }
    }
  }
}

function drawPlayer() {
  const { x, y, width, height, grounded, velocityY } = state.player;

  ctx.fillStyle = "rgba(0, 0, 0, 0.14)";
  ctx.beginPath();
  ctx.ellipse(x + width / 2, groundSurfaceY() + 8, width * 0.36, 10, 0, 0, Math.PI * 2);
  ctx.fill();

  const drawWidth = TILE_SIZE * 1.55;
  const drawHeight = TILE_SIZE * 1.55;
  const drawX = x - TILE_SIZE * 0.36;
  const drawY = y - TILE_SIZE * 0.24;
  const runFrame = playerFrames.run[Math.floor(performance.now() / 110) % playerFrames.run.length];
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

function drawGoalMarker() {
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
}

function draw() {
  drawBackdrop();
  drawTiles();
  drawPlayer();
  drawGoalMarker();
}

function loop(timestamp) {
  if (!state.lastTime) {
    state.lastTime = timestamp;
  }

  const delta = Math.min((timestamp - state.lastTime) / 1000, 0.05);
  state.lastTime = timestamp;

  update(delta);
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
playArea.addEventListener("pointerdown", (event) => {
  if (event.target === actionButton) {
    return;
  }

  handlePrimaryAction(event);
});
actionButton.addEventListener("click", (event) => {
  event.preventDefault();
  if (state.phase === "running") {
    jump();
    return;
  }

  startGame();
});

resetGame();
requestAnimationFrame(loop);
