<?php
$host = $_SERVER['HTTP_HOST'];

if ($host == 'dev.dtch.online') {
    echo "You are on the development!";
}
?>

<nav>
    <ul>
        <li><a href="index.php">Home</a></li>
        <li><a href="clan_stats.php">Clan Stats</a></li>
        <li><a href="user_stats.php">User Stats</a></li>
        <li><a href="topstats.php">Top10</a></li>
        <li><a href="topstatsavg.php">Match % T10</a></li>
        <li><a href="latestmatches.php">Last Matches</a></li>
        <li><a href="last_stats.php">Last 14 days %</a></li>

    </ul>
</nav>
