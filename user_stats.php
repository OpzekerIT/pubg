<?php
$ogDescription = "Explore detailed lifetime statistics of PUBG players in various game modes including solo, duo, and squad. Choose your favorite mode and player to view their performance stats, victories, and more, updated regularly.";
?>

<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; ?>
<body>

<?php 
include './includes/navigation.php';
include './includes/header.php';
?>

<main>
    <section>
        <h2>User Stats</h2>
        <?php
            include './config/config.php';

            $players_data = json_decode(file_get_contents('./data/player_lifetime_data.json'), true);

            $selected_mode = isset($_GET['game_mode']) ? $_GET['game_mode'] : 'squad';

            // Form to select game mode
            echo "<form method='get' action=''>
                    <input type='submit' name='game_mode' value='solo' class='btn'>
                    <input type='submit' name='game_mode' value='duo' class='btn'>
                    <input type='submit' name='game_mode' value='squad' class='btn'>

                    <input type='submit' name='game_mode' value='solo-fpp' class='btn'>
                    <input type='submit' name='game_mode' value='duo-fpp' class='btn'>
                    <input type='submit' name='game_mode' value='squad-fpp' class='btn'>
                  </form><br>";

            // Buttons for each player
            echo "<form method='get' action=''>";
            foreach ($players_data[$selected_mode] as $player_name => $player_details) {
                echo "<button type='submit' name='selected_player' value='$player_name' class='btn' >$player_name</button>";
                
            }
            echo "<input type='hidden' name='game_mode' value='$selected_mode'>";
            echo "</form><br>";

            $selected_player = $_GET['selected_player'] ?? array_key_first($players_data[$selected_mode]);

            // Fetch the player stats based on game mode and selected player
            if (isset($players_data[$selected_mode][$selected_player])) {
                $account_id = array_key_first($players_data[$selected_mode][$selected_player]);
                $stats = $players_data[$selected_mode][$selected_player][$account_id];

                echo "<h2>" . ucfirst($selected_mode) . " Lifetime Stats for $selected_player</h2>";
                echo "<table border='1'>";
                echo "<tr><th>Stat Name</th><th>Value</th></tr>";
                foreach ($stats as $stat_name => $stat_value) {
                    echo "<tr><td>$stat_name</td><td>$stat_value</td></tr>";
                }
                echo "</table><br>";
            } else {
                echo "No player data available.";
            }
            echo "Last update " ;
            echo $players_data['updated'];
        ?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
