<?php
session_start();

$allowed_refreshes = 3; 
$allowed_time = 10; 


if (!isset($_SESSION['access_times'])) {
    $_SESSION['access_times'] = [];
}


$now = time();
$_SESSION['access_times'][] = $now;


foreach ($_SESSION['access_times'] as $key => $timestamp) {
    if ($now - $timestamp > $allowed_time) {
        unset($_SESSION['access_times'][$key]);
    }
}


if (count($_SESSION['access_times']) > $allowed_refreshes) {
    die('
    <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="3">
    <title>RustAGHH</title>
</head>
<body>
    <p>RUSTAAAGGHHHH je mag de pagina niet vaker dan ' . $allowed_refreshes . 'x per ' . $allowed_time . ' seconde refreshen. Over een paar seconden wordt je weer teruggeleid.</p>
</body>
</html>
');
}


?>
