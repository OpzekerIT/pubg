<?php
$host = $_SERVER['HTTP_HOST'];

if ($host == 'dev.dtch.online') {
    echo "You are on the development! Site";
}
?>
<div class="topnav">
    <a href="index.php" class="active">Logo</a>

    <div id="myLinks">
        <a href="clan_stats.php">Clan Stats</a>
        <a href="user_stats.php">User Stats</a>
        <a href="topstats.php">Top10</a>
        <a href="topstatsavg.php">Match % T10</a>
        <a href="latestmatches.php">Last Matches</a>
        <a href="last_stats.php">Last 14 days %</a>
    </div>
    <a href="javascript:void(0);" class="icon" onclick="myFunction()">
        <i class="fa fa-bars"></i>
    </a>
</div>

function myFunction() {
  var x = document.getElementById("myLinks");
  if (x.style.display === "block") {
    x.style.display = "none";
  } else {
    x.style.display = "block";
  }
}