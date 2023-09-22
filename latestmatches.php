<?php

// Sample data from the API
$data = json_decode(file_get_contents('./data/player_data.json'), true); // Replace 'YOUR_JSON_DATA_HERE' with the JSON data you've provided

// Extract details
$mapName = $data['data']['attributes']['mapName'];
$matchType = $data['data']['attributes']['matchType'];

$participants = [];

// Find all participants in the "included" section
foreach ($data['included'] as $include) {
    if ($include['type'] === 'participant') {
        $participants[$include['id']] = $include['attributes']['stats'];
    }
}

echo '<table border="1">';
echo '<tr>';
echo '<th>Name</th>';
echo '<th>DBNOs</th>';
echo '<th>Assists</th>';
echo '<th>Headshot Kills</th>';
echo '<th>Kills</th>';
echo '<th>Revives</th>';
echo '</tr>';

// Iterate through rosters and link players to participants
foreach ($data['data']['relationships']['rosters']['data'] as $roster) {
    foreach ($data['included'] as $include) {
        if ($include['type'] === 'roster' && $include['id'] === $roster['id']) {
            foreach ($include['relationships']['participants']['data'] as $participant) {
                if (isset($participants[$participant['id']])) {
                    echo '<tr>';
                    echo '<td>' . $participants[$participant['id']]['name'] . '</td>';
                    echo '<td>' . $participants[$participant['id']]['DBNOs'] . '</td>';
                    echo '<td>' . $participants[$participant['id']]['assists'] . '</td>';
                    echo '<td>' . $participants[$participant['id']]['headshotKills'] . '</td>';
                    echo '<td>' . $participants[$participant['id']]['kills'] . '</td>';
                    echo '<td>' . $participants[$participant['id']]['revives'] . '</td>';
                    echo '</tr>';
                }
            }
        }
    }
}

echo '</table>';
echo '<p>Map Name: ' . $mapName . '</p>';
echo '<p>Match Type: ' . $matchType . '</p>';

?>
