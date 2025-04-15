<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Welcome to the epicenter of PUBG action! Catch up on the latest matches with detailed stats including player names, match dates, modes, types, maps, kills, and more. Plus, get an inside look at our clan's profile, including member details and key attributes. Stay connected with the pulse of our PUBG community!";

// Include map names mapping
include './includes/mapsmap.php'; // Contains the $mapNames array

// --- Latest Matches Data ---
$matchesJsonPath = 'data/player_matches.json';
$lastMatches = [];
$matchesError = '';

if (file_exists($matchesJsonPath)) {
    $jsonData = file_get_contents($matchesJsonPath);
    $playersData = json_decode($jsonData, true);

    if (is_array($playersData)) {
        // Combine matches from all players
        $allMatches = [];
        foreach ($playersData as $player) {
            if (isset($player['player_matches']) && is_array($player['player_matches'])) {
                foreach ($player['player_matches'] as $match) {
                    $match['playername'] = $player['playername'] ?? 'Unknown'; // Add playername to each match for reference
                    $allMatches[] = $match;
                }
            }
        }

        // Sort matches by createdAt date (descending)
        usort($allMatches, function ($a, $b) {
            $timeA = isset($a['createdAt']) ? strtotime($a['createdAt']) : 0;
            $timeB = isset($b['createdAt']) ? strtotime($b['createdAt']) : 0;
            return $timeB - $timeA;
        });

        // Get the last 8 matches
        $lastMatches = array_slice($allMatches, 0, 8);
    } else {
        $matchesError = "Error decoding player matches data.";
    }
} else {
    $matchesError = "Player matches data file not found.";
}

// --- Clan Info Data ---
$clanInfoPath = './data/claninfo.json';
$clanmembersfile = './config/clanmembers.json';
$rankedfile = './data/player_season_data.json';

$clan = null;
$playerRanks = null;
$clanInfoError = '';

if (file_exists($clanInfoPath)) {
    $clanJson = file_get_contents($clanInfoPath);
    $clan = json_decode($clanJson, true);
    if (!is_array($clan)) {
        $clanInfoError = "Error decoding clan info data.";
        $clan = null;
    }
} else {
    $clanInfoError = "Clan info file missing.";
}

if (file_exists($rankedfile)) {
    $rankedJson = file_get_contents($rankedfile);
    $playerRanks = json_decode($rankedJson, true);
    if (!is_array($playerRanks)) {
        $clanInfoError .= " Error decoding player rank data.";
        $playerRanks = null;
    }
} else {
    $clanInfoError .= " Player rank file missing.";
}

// Note: $clanmembers is read but not used directly in this refactored version's display logic.
// If needed elsewhere, ensure file_exists check is added.
// $clanmembers = file_exists($clanmembersfile) ? json_decode(file_get_contents($clanmembersfile), true) : null;

?>
<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; // Includes $ogDescription ?>

<body>
    <?php
    include './includes/navigation.php';
    include './includes/header.php';
    ?>
    <main>
        <section>
            <h2>Latest Matches</h2>
            <?php if ($matchesError): ?>
                <p style="color: red;"><?php echo htmlspecialchars($matchesError); ?></p>
            <?php elseif (empty($lastMatches)): ?>
                <p>No recent matches found.</p>
            <?php else: ?>
                <table>
                    <thead>
                        <tr>
                            <th>Player Name</th>
                            <th>Match Date</th>
                            <th>Mode</th>
                            <th>Type</th>
                            <th>Map</th>
                            <th>Kills</th>
                            <th>Damage</th>
                            <th>Place</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($lastMatches as $match):
                            $matchid = htmlspecialchars($match['id'] ?? '');
                            $playerName = htmlspecialchars($match['playername'] ?? 'N/A');
                            $gameMode = htmlspecialchars($match['gameMode'] ?? 'N/A');
                            $matchType = htmlspecialchars($match['matchType'] ?? 'N/A');
                            $mapNameRaw = $match['mapName'] ?? 'N/A';
                            $mapName = htmlspecialchars(isset($mapNames[$mapNameRaw]) ? $mapNames[$mapNameRaw] : $mapNameRaw);
                            $kills = htmlspecialchars($match['stats']['kills'] ?? 'N/A');
                            $damageDealt = isset($match['stats']['damageDealt']) ? number_format($match['stats']['damageDealt'], 0, '.', '') : 'N/A';
                            $winPlace = htmlspecialchars($match['stats']['winPlace'] ?? 'N/A');
                            $createdAt = $match['createdAt'] ?? null;
                            $formattedDate = 'N/A';
                            if ($createdAt) {
                                try {
                                    $date = new DateTime($createdAt);
                                    $date->modify('+1 hours'); // Adjust timezone or add offset as needed
                                    $formattedDate = $date->format('m-d H:i:s');
                                } catch (Exception $e) {
                                    $formattedDate = 'Invalid Date';
                                }
                            }
                        ?>
                        <tr>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $playerName; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $formattedDate; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $gameMode; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $matchType; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $mapName; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $kills; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $damageDealt; ?></a></td>
                            <td><a href="matchinfo.php?matchid=<?php echo $matchid; ?>"><?php echo $winPlace; ?></a></td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </section>

        <section>
            <h2>Clan Info</h2>
            <?php if ($clanInfoError && !$clan && !$playerRanks): ?>
                <p style="color: red;"><?php echo htmlspecialchars(trim($clanInfoError)); ?></p>
            <?php else: ?>
                <?php if ($clanInfoError): // Show non-fatal errors ?>
                    <p style="color: orange;"><?php echo htmlspecialchars(trim($clanInfoError)); ?></p>
                <?php endif; ?>

                <?php if (isset($clan) && !empty($clan)): ?>
                    <table class="sortable">
                        <thead>
                            <tr><th>Attribute</th><th>Value</th><th>Rank (FPP SQUAD)</th><th>Points</th></tr>
                        </thead>
                        <tbody>
                            <?php if (isset($playerRanks) && is_array($playerRanks)): ?>
                                <?php foreach ($playerRanks as $rank):
                                    $playername = htmlspecialchars($rank['name'] ?? 'N/A');
                                    $playerLink = 'latestmatches.php?selected_player=' . urlencode($rank['name'] ?? '');
                                    $tier = 'Unranked';
                                    $subTier = '';
                                    $image = './images/ranks/Unranked.webp';
                                    $rankPoint = '';

                                    if (isset($rank['stat']['data']['attributes']['rankedGameModeStats']['squad-fpp'])) {
                                        $squadFppStats = $rank['stat']['data']['attributes']['rankedGameModeStats']['squad-fpp'];
                                        $tier = htmlspecialchars($squadFppStats['currentTier']['tier'] ?? 'N/A');
                                        $subTier = htmlspecialchars($squadFppStats['currentTier']['subTier'] ?? '');
                                        $image = "./images/ranks/" . $tier . "-" . $subTier . ".webp";
                                        $rankPoint = htmlspecialchars($squadFppStats['currentRankPoint'] ?? '');
                                    }
                                    $altText = $tier . ($subTier ? '-' . $subTier : '');
                                ?>
                                <tr>
                                    <td><a href="<?php echo $playerLink; ?>">name</a></td>
                                    <td><a href="<?php echo $playerLink; ?>"><?php echo $playername; ?></a></td>
                                    <td><img src="<?php echo htmlspecialchars($image); ?>" class="table-image" alt="<?php echo htmlspecialchars($altText); ?>"></td>
                                    <td><?php echo $rankPoint; ?></td>
                                </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>

                            <?php foreach ($clan as $key => $value):
                                if ($key == 'updated') continue; // Skip updated timestamp
                                ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($key); ?></td>
                                    <td><?php echo htmlspecialchars(is_scalar($value) ? $value : json_encode($value)); ?></td>
                                    <td></td>
                                    <td></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php elseif (!$clanInfoError): // Only show if no error message was already displayed ?>
                    <p>No clan attributes available.</p>
                <?php endif; ?>
            <?php endif; ?>
        </section>
    </main>

    <?php include './includes/footer.php'; ?>
</body>
</html>