<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
?>

<?php //include './includes/ratelimiter.php'; ?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DTCH - PUBG Clan - Clan Stats</title>
    <link rel="stylesheet" href="./includes/styles.css">
</head>
<body>

<?php include './includes/navigation.php'; ?>

<main>
    <section>
        <h2>Clan Stats</h2>
        <?php
            include './config/config.php';

            $url = "https://api.pubg.com/shards/steam/clans/$clanid";
            $headers = array(
                'Authorization: Bearer ' . $apiKey,
                'Accept: application/vnd.api+json'
            );
            
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            $response = curl_exec($ch);
            curl_close($ch);
            $clan = json_decode($response, true);
            if (isset($clan['data']['attributes'])) {
                echo "<table>";
                echo "<tr><th>Attribute</th><th>Value</th></tr>";
                foreach ($clan['data']['attributes'] as $key => $value) {
                    echo "<tr><td>" . htmlspecialchars($key) . "</td><td>" . htmlspecialchars($value) . "</td></tr>";
                }
                echo "</table>";
            } else {
                echo "<p>No clan attributes available</p>";
            }
            
            
        ?>
    </section>
</main>

<?php include './includes/footer.php'; ?>

</body>
</html>
