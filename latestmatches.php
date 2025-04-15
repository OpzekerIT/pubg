<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Dive into the detailed match stats of DTCH Clan in PUBG. Explore recent matches, various game modes, and match types. View individual performance metrics like kills, damage dealt, and survival time for each clan member. Stay updated with the latest match stats and follow the clan's journey in PUBG.";

// Include required files
include './includes/mapsmap.php'; // Contains the $mapNames array
$configPath = './config/config.php';
if (file_exists($configPath)) {
    include $configPath;
}

$players_matches = null;
$clanMembers = [];
$filteredMatches = [];
$dataError = '';
$selected_player = null;
$filter_by_match_type = 'all'; // Default filter
$matchTypes = ['all', 'airoyale', 'official', 'custom', 'event', 'competitive']; // Available filter types

// Load clan members
$clanMembersPath = './config/clanmembers.json';
if (file_exists($clanMembersPath)) {
    $playersJson = file_get_contents($clanMembersPath);
    $playersData = json_decode($playersJson, true);
    if (isset($playersData['clanMembers']) && is_array($playersData['clanMembers'])) {
        $clanMembers = $playersData['clanMembers'];
    } else {
        $dataError .= " Error reading or invalid format in clan members file.";
    }
} else {
    $dataError .= " Clan members file not found.";
}

// Determine selected player
if (!empty($clanMembers)) {
    $selected_player_from_get = $_GET['selected_player'] ?? null;
    if ($selected_player_from_get && in_array($selected_player_from_get, $clanMembers)) {
        $selected_player = $selected_player_from_get;
    } else {
        $selected_player = $clanMembers[0]; // Default to the first clan member
    }
} else {
     $dataError .= " No clan members loaded to select from.";
}

// Determine selected match type filter
$filter_from_get = $_GET['filter_by_match_type'] ?? 'all';
if (in_array($filter_from_get, $matchTypes)) {
    $filter_by_match_type = $filter_from_get;
}

// Load cached matches data
$matchesPath = './data/cached_matches.json';
if (file_exists($matchesPath)) {
    $matchesJson = file_get_contents($matchesPath);
    $players_matches = json_decode($matchesJson, true);

    if (!is_array($players_matches)) {
        $dataError .= " Error decoding cached matches data.";
        $players_matches = null;
    } elseif ($selected_player) {
        // Filter matches for the selected player and match type
        foreach ($players_matches as $match) {
            if (!isset($match['stats']) || !is_array($match['stats'])) continue;

            foreach ($match['stats'] as $stats) {
                if (isset($stats['name']) && $stats['name'] === $selected_player) {
                    // Apply match type filter
                    $matchType = $match['matchType'] ?? null;
                    if ($filter_by_match_type === 'all' || $matchType === $filter_by_match_type) {
                        // Prepare data for display
                        $displayMatch = [];
                        $displayMatch['id'] = $match['id'] ?? null;
                        $displayMatch['matchType'] = $matchType;
                        $displayMatch['gameMode'] = $match['gameMode'] ?? 'N/A';
                        $mapNameRaw = $match['mapName'] ?? 'N/A';
                        $displayMatch['mapName'] = isset($mapNames[$mapNameRaw]) ? $mapNames[$mapNameRaw] : $mapNameRaw;
                        $displayMatch['kills'] = $stats['kills'] ?? 'N/A';
                        $displayMatch['damageDealt'] = isset($stats['damageDealt']) ? number_format($stats['damageDealt'], 0, '.', '') : 'N/A';
                        $displayMatch['timeSurvived'] = $stats['timeSurvived'] ?? 'N/A';
                        $displayMatch['winPlace'] = $stats['winPlace'] ?? 'N/A';
                        $createdAt = $match['createdAt'] ?? null;
                        $displayMatch['formattedDate'] = 'N/A';
                        if ($createdAt) {
                            try {
                                $date = new DateTime($createdAt);
                                $date->modify('+1 hours'); // Adjust timezone or add offset as needed
                                $displayMatch['formattedDate'] = $date->format('m-d H:i:s');
                            } catch (Exception $e) {
                                $displayMatch['formattedDate'] = 'Invalid Date';
                            }
                        }
                        $filteredMatches[] = $displayMatch;
                    }
                    break; // Found the selected player in this match, move to the next match
                }
            }
        }
         if (empty($filteredMatches) && !$dataError) {
             $dataError .= " No matches found for " . htmlspecialchars($selected_player) . ($filter_by_match_type !== 'all' ? " with type '" . htmlspecialchars($filter_by_match_type) . "'" : "") . ".";
         }
    }
} else {
    $dataError .= " Cached matches data file not found.";
}

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
            <h2>Match Stats</h2>

            <?php if (trim($dataError)): ?>
                <p style="color: red;"><?php echo htmlspecialchars(trim($dataError)); ?></p>
            <?php endif; ?>

            <!-- Player Selection Form -->
            <?php if (!empty($clanMembers)): ?>
                <form method="get" action="">
                    <?php foreach ($clanMembers as $player): ?>
                        <button type="submit" name="selected_player" value="<?php echo htmlspecialchars($player); ?>" class="btn<?php echo ($player === $selected_player) ? ' active' : ''; ?>">
                            <?php echo htmlspecialchars($player); ?>
                        </button>
                    <?php endforeach; ?>
                    <?php // Keep filter if player changes ?>
                    <input type="hidden" name="filter_by_match_type" value="<?php echo htmlspecialchars($filter_by_match_type); ?>">
                </form>
                <br>
            <?php endif; ?>

             <!-- Match Type Filter Form -->
            <?php if ($selected_player): ?>
                <form method="get" action="">
                    <?php foreach ($matchTypes as $type): ?>
                         <input type="submit" name="filter_by_match_type" value="<?php echo htmlspecialchars($type); ?>" class="btn<?php echo ($type === $filter_by_match_type) ? ' active' : ''; ?>">
                    <?php endforeach; ?>
                    <input type="hidden" name="selected_player" value="<?php echo htmlspecialchars($selected_player); ?>">
                </form>
                <br>
            <?php endif; ?>


            <?php if ($selected_player && !empty($filteredMatches)): ?>
                <h2>Recent Matches for <?php echo htmlspecialchars($selected_player); ?> (<?php echo htmlspecialchars(ucfirst($filter_by_match_type)); ?>)</h2>
                <table border="1" class="sortable">
                    <thead>
                        <tr>
                            <th>Match Date</th>
                            <th>Game Mode</th>
                            <th>Match Type</th>
                            <th>Map</th>
                            <th>Kills</th>
                            <th>Damage Dealt</th>
                            <th>Time Survived (s)</th>
                            <th>Win Place</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($filteredMatches as $match):
                            $matchIdLink = 'matchinfo.php?matchid=' . urlencode($match['id'] ?? '');
                        ?>
                            <tr>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['formattedDate']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['gameMode']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['matchType']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['mapName']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['kills']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['damageDealt']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['timeSurvived']); ?></a></td>
                                <td><a href="<?php echo $matchIdLink; ?>"><?php echo htmlspecialchars($match['winPlace']); ?></a></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
                <br>
            <?php elseif ($selected_player && !$dataError): ?>
                 <p>No matches found for the selected criteria.</p>
            <?php endif; ?>
        </section>
    </main>

    <?php include './includes/footer.php'; ?>

</body>
</html>