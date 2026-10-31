const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// ============================================================
// CONFIG
// ============================================================

const PORT = process.env.PORT || 5000;

const MONGO_URI =
  process.env.MONGO_URI ||
  'mongodb://127.0.0.1:27017/bubble_blast_adventure';

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors());
app.use(express.json());

// ============================================================
// DATABASE
// ============================================================

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('============================================');
    console.log('MongoDB connected successfully');
    console.log('============================================');
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
  });

// ============================================================
// PLAYER SCHEMA
// ============================================================

const playerSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },

    age: {
      type: Number,
      required: true,
      min: 5,
      max: 100,
    },

    password: {
      type: String,
      required: true,
    },

    avatarIndex: {
      type: Number,
      default: 0,
    },

    currentLevel: {
      type: Number,
      default: 1,
      min: 1,
    },

    currentScore: {
      type: Number,
      default: 0,
    },

    highestScore: {
      type: Number,
      default: 0,
    },

    totalStars: {
      type: Number,
      default: 0,
    },

    gamesWon: {
      type: Number,
      default: 0,
    },

    gamesLost: {
      type: Number,
      default: 0,
    },

    totalGamesPlayed: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

const Player = mongoose.model('Player', playerSchema);

// ============================================================
// SCORE SCHEMA
// ============================================================

const scoreSchema = new mongoose.Schema(
  {
    playerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Player',
      required: true,
    },

    playerName: {
      type: String,
      required: true,
    },

    levelNumber: {
      type: Number,
      required: true,
    },

    score: {
      type: Number,
      required: true,
    },

    stars: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

const Score = mongoose.model('Score', scoreSchema);

// ============================================================
// FORMAT PLAYER
// ============================================================

function formatPlayer(player) {
  return {
    id: player._id.toString(),
    name: player.name,
    email: player.email,
    age: player.age,

    avatarIndex: player.avatarIndex ?? 0,

    currentLevel: player.currentLevel ?? 1,
    currentScore: player.currentScore ?? 0,
    highestScore: player.highestScore ?? 0,
    totalStars: player.totalStars ?? 0,

    gamesWon: player.gamesWon ?? 0,
    gamesLost: player.gamesLost ?? 0,
    totalGamesPlayed: player.totalGamesPlayed ?? 0,

    createdAt: player.createdAt,
    updatedAt: player.updatedAt,
  };
}

// ============================================================
// ROOT
// ============================================================

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Bubble Blast Adventure server is running',
  });
});

// ============================================================
// CREATE PLAYER
// POST /api/players
// ============================================================

app.post('/api/players', async (req, res) => {
  try {
    console.log('');
    console.log('CREATE PLAYER');
    console.log(req.body);

    const {
      name,
      playerName,
      email,
      age,
      password,
      avatarIndex,
    } = req.body;

    const finalName =
      name?.toString().trim() ||
      playerName?.toString().trim();

    const finalEmail =
      email?.toString().trim().toLowerCase();

    const finalAge = Number(age);

    // --------------------------------------------------------
    // VALIDATION
    // --------------------------------------------------------

    if (
      !finalName ||
      !finalEmail ||
      !password ||
      age === undefined ||
      age === null
    ) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, age and password are required',
      });
    }

    if (finalName.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Name must contain at least 2 characters',
      });
    }

    if (
      Number.isNaN(finalAge) ||
      finalAge < 5 ||
      finalAge > 100
    ) {
      return res.status(400).json({
        success: false,
        message: 'Age must be between 5 and 100',
      });
    }

    if (password.toString().length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    // --------------------------------------------------------
    // DUPLICATE EMAIL
    // --------------------------------------------------------

    const existingPlayer = await Player.findOne({
      email: finalEmail,
    });

    if (existingPlayer) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists',
      });
    }

    // --------------------------------------------------------
    // CREATE
    // --------------------------------------------------------

    const player = await Player.create({
      name: finalName,
      email: finalEmail,
      age: finalAge,
      password: password.toString(),

      avatarIndex:
        avatarIndex !== undefined
          ? Number(avatarIndex)
          : 0,

      currentLevel: 1,
      currentScore: 0,
      highestScore: 0,
      totalStars: 0,

      gamesWon: 0,
      gamesLost: 0,
      totalGamesPlayed: 0,
    });

    console.log(
      `Profile created: ${player.name} (${player._id})`
    );

    return res.status(201).json({
      success: true,
      message: 'Profile created successfully',
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error('Create player error:', error);

    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists',
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Server error while creating profile',
    });
  }
});

// ============================================================
// REGISTER ALIAS
// POST /api/players/register
// ============================================================

app.post('/api/players/register', async (req, res) => {
  req.body = {
    ...req.body,
  };

  // Use the same creation logic
  try {
    const {
      name,
      playerName,
      email,
      age,
      password,
      avatarIndex,
    } = req.body;

    const finalName =
      name?.toString().trim() ||
      playerName?.toString().trim();

    const finalEmail =
      email?.toString().trim().toLowerCase();

    const finalAge = Number(age);

    if (
      !finalName ||
      !finalEmail ||
      !password ||
      age === undefined ||
      age === null
    ) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, age and password are required',
      });
    }

    if (finalName.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Name must contain at least 2 characters',
      });
    }

    if (
      Number.isNaN(finalAge) ||
      finalAge < 5 ||
      finalAge > 100
    ) {
      return res.status(400).json({
        success: false,
        message: 'Age must be between 5 and 100',
      });
    }

    if (password.toString().length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
      });
    }

    const existingPlayer = await Player.findOne({
      email: finalEmail,
    });

    if (existingPlayer) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists',
      });
    }

    const player = await Player.create({
      name: finalName,
      email: finalEmail,
      age: finalAge,
      password: password.toString(),
      avatarIndex:
        avatarIndex !== undefined
          ? Number(avatarIndex)
          : 0,

      currentLevel: 1,
      currentScore: 0,
      highestScore: 0,
      totalStars: 0,
      gamesWon: 0,
      gamesLost: 0,
      totalGamesPlayed: 0,
    });

    return res.status(201).json({
      success: true,
      message: 'Profile created successfully',
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error('Register error:', error);

    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'An account with this email already exists',
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Server error while creating profile',
    });
  }
});

// ============================================================
// LOGIN
// POST /api/players/login
// ============================================================

app.post('/api/players/login', async (req, res) => {
  try {
    console.log('');
    console.log('LOGIN REQUEST');
    console.log(req.body);

    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required',
      });
    }

    const cleanEmail =
      email.toString().trim().toLowerCase();

    const player = await Player.findOne({
      email: cleanEmail,
    });

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'No profile found with this email',
      });
    }

    if (player.password !== password.toString()) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password',
      });
    }

    console.log(
      `Login successful: ${player.name}`
    );

    return res.status(200).json({
      success: true,
      message: 'Login successful',
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error('Login error:', error);

    return res.status(500).json({
      success: false,
      message: 'Server error while logging in',
    });
  }
});

// ============================================================
// GET ALL PLAYERS
// ============================================================

app.get('/api/players', async (req, res) => {
  try {
    const players = await Player.find({})
      .sort({
        highestScore: -1,
        totalStars: -1,
        currentLevel: -1,
      });

    res.status(200).json({
      success: true,
      players: players.map(formatPlayer),
    });
  } catch (error) {
    console.error('Get players error:', error);

    res.status(500).json({
      success: false,
      message: 'Unable to load players',
    });
  }
});

// ============================================================
// GET ONE PLAYER
// ============================================================

app.get('/api/players/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid player ID',
      });
    }

    const player =
      await Player.findById(req.params.id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'Player not found',
      });
    }

    return res.status(200).json({
      success: true,
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error('Get player error:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to get player',
    });
  }
});

// ============================================================
// UPDATE PLAYER PROFILE
// ============================================================

app.put('/api/players/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid player ID',
      });
    }

    const player =
      await Player.findById(req.params.id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'Player not found',
      });
    }

    const {
      name,
      email,
      age,
      password,
      avatarIndex,
    } = req.body;

    if (name !== undefined) {
      const cleanName =
        name.toString().trim();

      if (cleanName.length < 2) {
        return res.status(400).json({
          success: false,
          message:
            'Name must contain at least 2 characters',
        });
      }

      player.name = cleanName;
    }

    if (email !== undefined) {
      const cleanEmail =
        email.toString().trim().toLowerCase();

      const duplicate =
        await Player.findOne({
          email: cleanEmail,
          _id: { $ne: player._id },
        });

      if (duplicate) {
        return res.status(409).json({
          success: false,
          message:
            'This email is already used by another profile',
        });
      }

      player.email = cleanEmail;
    }

    if (age !== undefined) {
      const newAge = Number(age);

      if (
        Number.isNaN(newAge) ||
        newAge < 5 ||
        newAge > 100
      ) {
        return res.status(400).json({
          success: false,
          message: 'Age must be between 5 and 100',
        });
      }

      player.age = newAge;
    }

    if (password !== undefined &&
        password.toString().length >= 6) {
      player.password =
        password.toString();
    }

    if (avatarIndex !== undefined) {
      player.avatarIndex =
        Number(avatarIndex);
    }

    await player.save();

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error('Update profile error:', error);

    return res.status(500).json({
      success: false,
      message: 'Unable to update profile',
    });
  }
});

// ============================================================
// UPDATE GAME PROGRESS
// ============================================================

app.put('/api/players/:id/progress', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid player ID',
      });
    }

    const player =
      await Player.findById(req.params.id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'Player not found',
      });
    }

    const {
      currentLevel,
      currentScore,
      highestScore,
      totalStars,
      gameWon,
      gameLost,
      starsEarned,
    } = req.body;

    // --------------------------------------------------------
    // CURRENT LEVEL
    // --------------------------------------------------------

    if (currentLevel !== undefined) {
      const newLevel =
        Number(currentLevel);

      if (!Number.isNaN(newLevel)) {
        player.currentLevel =
          Math.max(
            player.currentLevel,
            newLevel
          );
      }
    }

    // --------------------------------------------------------
    // CURRENT SCORE
    // --------------------------------------------------------

    if (currentScore !== undefined) {
      const newScore =
        Number(currentScore);

      if (!Number.isNaN(newScore)) {
        player.currentScore =
          newScore;
      }
    }

    // --------------------------------------------------------
    // HIGHEST SCORE
    // --------------------------------------------------------

    if (highestScore !== undefined) {
      const newHighest =
        Number(highestScore);

      if (!Number.isNaN(newHighest)) {
        player.highestScore =
          Math.max(
            player.highestScore,
            newHighest
          );
      }
    }

    // --------------------------------------------------------
    // ⭐ STARS
    //
    // IMPORTANT:
    // Stars can ONLY increase when gameWon === true.
    // --------------------------------------------------------

    if (gameWon === true) {
      const earned =
        Number(starsEarned ?? 0);

      if (
        !Number.isNaN(earned) &&
        earned > 0
      ) {
        player.totalStars += earned;
      }

      player.gamesWon += 1;
      player.totalGamesPlayed += 1;
    }

    // --------------------------------------------------------
    // LOST GAME
    //
    // NO STARS ARE ADDED.
    // --------------------------------------------------------

    if (gameLost === true) {
      player.gamesLost += 1;
      player.totalGamesPlayed += 1;
    }

    // Optional direct totalStars update only if explicitly
    // provided and it is greater than the current value.
    // But normal game flow should use starsEarned.
    if (
      totalStars !== undefined &&
      gameWon === true
    ) {
      const requestedStars =
        Number(totalStars);

      if (
        !Number.isNaN(requestedStars) &&
        requestedStars > player.totalStars
      ) {
        player.totalStars =
          requestedStars;
      }
    }

    await player.save();

    return res.status(200).json({
      success: true,
      message: 'Player progress updated',
      player: formatPlayer(player),
    });
  } catch (error) {
    console.error(
      'Progress update error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to update player progress',
    });
  }
});

// ============================================================
// DELETE PLAYER
// ============================================================

app.delete('/api/players/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid player ID',
      });
    }

    const player =
      await Player.findById(req.params.id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'Player not found',
      });
    }

    await Score.deleteMany({
      playerId: player._id,
    });

    await Player.findByIdAndDelete(
      req.params.id
    );

    return res.status(200).json({
      success: true,
      message: 'Profile deleted successfully',
    });
  } catch (error) {
    console.error(
      'Delete player error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to delete profile',
    });
  }
});

// ============================================================
// SAVE SCORE
// ============================================================

app.post('/api/scores', async (req, res) => {
  try {
    const {
      playerId,
      playerName,
      levelNumber,
      score,
      stars,
    } = req.body;

    if (
      !playerId ||
      !playerName ||
      levelNumber === undefined ||
      score === undefined
    ) {
      return res.status(400).json({
        success: false,
        message:
          'Player, level and score are required',
      });
    }

    if (!mongoose.Types.ObjectId.isValid(playerId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid player ID',
      });
    }

    const player =
      await Player.findById(playerId);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: 'Player not found',
      });
    }

    // Stars are stored as 0 if the level was not won.
    const finalStars =
      Number(stars ?? 0);

    const newScore =
      await Score.create({
        playerId,
        playerName,
        levelNumber: Number(levelNumber),
        score: Number(score),
        stars:
          finalStars > 0
            ? finalStars
            : 0,
      });

    return res.status(201).json({
      success: true,
      message: 'Score saved successfully',
      score: newScore,
    });
  } catch (error) {
    console.error(
      'Save score error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to save score',
    });
  }
});

// ============================================================
// LEADERBOARD
// ============================================================

app.get('/api/scores', async (req, res) => {
  try {
    const scores =
      await Score.find({})
        .sort({
          score: -1,
          stars: -1,
          createdAt: 1,
        })
        .limit(50);

    return res.status(200).json({
      success: true,
      scores,
    });
  } catch (error) {
    console.error(
      'Leaderboard error:',
      error
    );

    return res.status(500).json({
      success: false,
      message: 'Unable to load leaderboard',
    });
  }
});

// ============================================================
// 404
// ============================================================

app.use((req, res) => {
  console.log(
    `Route not found: ${req.method} ${req.originalUrl}`
  );

  res.status(404).json({
    success: false,
    message:
      `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// ============================================================
// ERROR HANDLER
// ============================================================

app.use((error, req, res, next) => {
  console.error(
    'Unhandled server error:',
    error
  );

  res.status(500).json({
    success: false,
    message: 'Internal server error',
  });
});

// ============================================================
// START
// ============================================================

app.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('============================================');
  console.log('     BUBBLE BLAST ADVENTURE SERVER');
  console.log('============================================');
  console.log(`Server:     http://localhost:${PORT}`);
  console.log(`Players:    http://localhost:${PORT}/api/players`);
  console.log(`Login:      http://localhost:${PORT}/api/players/login`);
  console.log(`Leaderboard:http://localhost:${PORT}/api/scores`);
  console.log('============================================');
  console.log('');
});