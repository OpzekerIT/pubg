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
    // Set HTTP status code for rate limiting
    http_response_code(429); // Too Many Requests
?>
<!DOCTYPE html>
<html lang="nl">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5;url=<?php echo htmlspecialchars($_SERVER['REQUEST_URI']); ?>">
    <title>Te Veel Verzoeken</title>
    <style>
        body { font-family: sans-serif; padding: 20px; background-color: #f8f8f8; color: #333; }
        .container { max-width: 600px; margin: 50px auto; background-color: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }
        h1 { color: #d9534f; }
        p { line-height: 1.6; }
        .timer { font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rustâââgh!</h1>
        <p>Je probeert de pagina te vaak te vernieuwen (meer dan <?php echo $allowed_refreshes; ?> keer per <?php echo $allowed_time; ?> seconden).</p>
        <p>Wacht even, je wordt over <span id="countdown" class="timer">5</span> seconden automatisch teruggestuurd.</p>
    </div>
    <script>
        let seconds = 5;
        const countdownElement = document.getElementById('countdown');
        const interval = setInterval(() => {
            seconds--;
            countdownElement.textContent = seconds;
            if (seconds <= 0) {
                clearInterval(interval);
                // Optional: You could redirect here as well, but meta refresh handles it
                // window.location.href = "<?php echo htmlspecialchars($_SERVER['REQUEST_URI']); ?>";
            }
        }, 1000);
    </script>
</body>
</html>
<?php
    exit; // Use exit instead of die for clarity
}

?>
