<?php
// --- Configuration and Data Fetching ---
$ogDescription = "Get in-depth insights into recent PUBG matches. Discover detailed match information including player stats, game modes, match types, and map names. Updated regularly to provide the latest and most comprehensive match data for PUBG enthusiasts.";

// Include map names mapping
include './includes/mapsmap.php'; // Contains the $mapNames array

$matchId = $_GET['matchid'] ?? null;
$matchDetails = null;
$killStats = [];
$participantStats = [];
$dataError = '';
$updateMessage = '';

if ($matchId) {
    $matchFilename = "data/matches/" . basename($matchId) . ".json"; // Use basename for security

    if (file_exists($matchFilename)) {
        $matchJsonData = file_get_contents($matchFilename);
        $matchData = json_decode($matchJsonData, true);

        if (is_array($matchData) && isset($matchData['data']['attributes']) && isset($matchData['included'])) {
            $matchDetails = $matchData['data']['attributes'];
            $matchDetails['id'] = $matchData['data']['id']; // Add id to details array

            // Prepare participant stats
            foreach ($matchData['included'] as $includedItem) {
                if ($includedItem['type'] == "participant") {
                    $participantStats[] = $includedItem['attributes']['stats'];
                }
            }

            // Check for killstats files
            $killstatsDirectory = 'data/killstats/';
            $killstatsPrefix = $matchData['data']['id'];
            $killstatsFiles = glob($killstatsDirectory . $killstatsPrefix . '_*.json'); // More specific glob pattern

            if (count($killstatsFiles) == 0) {
                // Calculate and display the "check back later" message
                try {
                    $currentTime = new DateTime('now', new DateTimeZone('UTC')); // Use UTC for consistency
                    $minutes = intval($currentTime->format('i'));
                    $minutesToNextUpdate = 30 - ($minutes % 30);
                    if ($minutesToNextUpdate === 30) $minutesToNextUpdate = 0; // Already on the half hour

                    if ($minutesToNextUpdate > 0) {
                        $updateMessage = "Kill stats are processing. Check back in $minutesToNextUpdate minutes. Data is updated every half hour.";
                    } else {
                        $updateMessage = "Kill stats data is updating, please check back shortly.";
                    }
                } catch (Exception $e) {
                     $updateMessage = "Could not determine update time."; // Handle potential DateTime errors
                }
            } else {
                // Process killstats files
                foreach ($killstatsFiles as $file) {
                    $killJsonData = json_decode(file_get_contents($file), true);
                    if (is_array($killJsonData) && isset($killJsonData['stats'])) {
                         $playerName = $killJsonData['stats']['playername'] ?? 'Unknown';
                         // Find corresponding participant for additional stats
                         $totalDamage = 'N/A';
                         $rank = 'N/A';
                         $dbnos = 'N/A';
                         foreach ($participantStats as $pStat) {
                             if (($pStat['name'] ?? null) === $playerName) {
                                 $totalDamage = $pStat['damageDealt'] ?? 'N/A';
                                 $rank = $pStat['winPlace'] ?? 'N/A';
                                 $dbnos = $pStat['DBNOs'] ?? 'N/A';
                                 break;
                             }
                         }
                         $killStats[] = [
                             'playername' => $playerName,
                             'humankills' => $killJsonData['stats']['humankills'] ?? 'N/A',
                             'HumanDmg' => $killJsonData['stats']['HumanDmg'] ?? 'N/A',
                             'kills' => $killJsonData['stats']['kills'] ?? 'N/A',
                             'totalDamage' => $totalDamage,
                             'rank' => $rank,
                             'DBNOs' => $dbnos
                         ];
                    }
                }
            }
        } else {
            $dataError = "Error decoding or invalid structure in match JSON file.";
        }
    } else {
        $dataError = "Match data file not found for the given match ID.";
    }
} else {
    $dataError = "No match ID provided.";
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
            <h2>Match Info</h2>

            <?php if ($dataError): ?>
                <p style="color: red;"><?php echo htmlspecialchars($dataError); ?></p>
            <?php elseif ($matchDetails):
                $mapNameRaw = $matchDetails['mapName'] ?? 'N/A';
                $mapDisplayName = htmlspecialchars(isset($mapNames[$mapNameRaw]) ? $mapNames[$mapNameRaw] : $mapNameRaw);
            ?>
                <h3>Match Details</h3>
                <table class='sortable'>
                    <thead>
                        <tr><th>Match Type</th><th>Game Mode</th><th>Duration (s)</th><th>Map</th><th>Date</th><th>ID</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><?php echo htmlspecialchars($matchDetails['matchType'] ?? 'N/A'); ?></td>
                            <td><?php echo htmlspecialchars($matchDetails['gameMode'] ?? 'N/A'); ?></td>
                            <td><?php echo htmlspecialchars($matchDetails['duration'] ?? 'N/A'); ?></td>
                            <td><?php echo $mapDisplayName; ?></td>
                            <td><?php echo htmlspecialchars($matchDetails['createdAt'] ?? 'N/A'); ?></td>
                            <td><?php echo htmlspecialchars($matchDetails['id'] ?? 'N/A'); ?></td>
                        </tr>
                    </tbody>
                </table>
                <br>

                <h3>Kill Stats</h3>
                <?php if ($updateMessage): ?>
                    <p><?php echo htmlspecialchars($updateMessage); ?></p>
                <?php elseif (!empty($killStats)): ?>
                    <table class='sortable'>
                        <thead>
                            <tr>
                                <th>Player Name</th>
                                <th>Human Kills</th>
                                <th>Human Dmg</th>
                                <th>Total Kills</th>
                                <th>Total Damage</th>
                                <th>Rank</th>
                                <th>DBNOs</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($killStats as $stat): ?>
                            <tr>
                                <td><?php echo htmlspecialchars($stat['playername']); ?></td>
                                <td><?php echo htmlspecialchars($stat['humankills']); ?></td>
                                <td><?php echo htmlspecialchars($stat['HumanDmg']); ?></td>
                                <td><?php echo htmlspecialchars($stat['kills']); ?></td>
                                <td><?php echo htmlspecialchars(is_numeric($stat['totalDamage']) ? number_format($stat['totalDamage'], 0) : $stat['totalDamage']); ?></td>
                                <td><?php echo htmlspecialchars($stat['rank']); ?></td>
                                <td><?php echo htmlspecialchars($stat['DBNOs']); ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                    <br>
                <?php else: ?>
                    <p>No kill stats available for this match.</p>
                <?php endif; ?>


                <h3>All Participants</h3>
                 <?php if (!empty($participantStats)): ?>
                    <table class='sortable'>
                        <thead>
                            <tr>
                                <th>Player Name</th>
                                <th>Type</th>
                                <th>Kills</th>
                                <th>Damage Dealt</th>
                                <th>Time Survived (s)</th>
                                <th>Rank</th>
                                <th>Revs</th>
                                <th>DBNOs</th>
                                <th>Assists</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($participantStats as $pStat):
                                $isBot = (isset($pStat['playerId']) && substr($pStat['playerId'], 0, 2) === 'ai');
                                $playerName = htmlspecialchars($pStat['name'] ?? 'N/A');
                                $playerLink = 'https://pubg.op.gg/user/' . urlencode($pStat['name'] ?? '');
                            ?>
                            <tr>
                                <td><?php echo $isBot ? $playerName : "<a href='{$playerLink}' target='_blank'>{$playerName}</a>"; ?></td>
                                <td><?php echo $isBot ? 'Bot' : 'Human'; ?></td>
                                <td><?php echo htmlspecialchars($pStat['kills'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars(isset($pStat['damageDealt']) ? number_format($pStat['damageDealt'], 0) : 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($pStat['timeSurvived'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($pStat['winPlace'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($pStat['revives'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($pStat['DBNOs'] ?? 'N/A'); ?></td>
                                <td><?php echo htmlspecialchars($pStat['assists'] ?? 'N/A'); ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                 <?php else: ?>
                    <p>No participant data available for this match.</p>
                 <?php endif; ?>

            <?php endif; // End check for $matchDetails ?>

        </section>
    </main>

    <?php include './includes/footer.php'; ?>
</body>
</html>