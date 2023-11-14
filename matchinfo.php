<?php
// Check if a match ID is provided in the GET request
if (isset($_GET['matchid'])) {
    $matchId = $_GET['matchid'];
    $filename = "data/matches/" . $matchId . ".json";

    // Check if the JSON file for the given match ID exists
    if (file_exists($filename)) {
        // Read and decode the JSON file
        $jsonData = json_decode(file_get_contents($filename), true);

        // Start building the HTML table
        echo "<table border='1'>";
        echo "<tr><th>Player Name</th><th>Kills</th><th>Damage Dealt</th><th>Time Survived</th><th>Rank</th></tr>";

        // Loop through the JSON data to extract player stats
        foreach ($jsonData['data']['relationships']['rosters']['data'] as $roster) {
            foreach ($jsonData['included'] as $includedItem) {
                if ($includedItem['type'] === 'participant' && in_array(['type' => 'participant', 'id' => $includedItem['id']], $roster['relationships']['participants']['data'])) {
                    $playerStats = $includedItem['attributes']['stats'];
                    echo "<tr>";
                    echo "<td>" . htmlspecialchars($playerStats['name']) . "</td>";
                    echo "<td>" . htmlspecialchars($playerStats['kills']) . "</td>";
                    echo "<td>" . htmlspecialchars($playerStats['damageDealt']) . "</td>";
                    echo "<td>" . htmlspecialchars($playerStats['timeSurvived']) . "</td>";
                    echo "<td>" . htmlspecialchars($playerStats['winPlace']) . "</td>";
                    echo "</tr>";
                }
            }
        }
        echo "</table>";
    } else {
        echo "JSON file not found for the given match ID.";
    }
} else {
    echo "No match ID provided.";
}
?>
