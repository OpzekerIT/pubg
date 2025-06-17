<?php
$ogDescription = "Bekijk alle video's";

// Scan the media/videos directory for mp4 files
$videosDir = __DIR__ . '/media/videos';
$allFiles = scandir($videosDir);
$videoFiles = array_filter($allFiles, function($file) use ($videosDir) {
    return is_file($videosDir . '/' . $file) && strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'mp4';
});

// Build array with creation time and sort by creation date descending
$videoData = [];
foreach ($videoFiles as $file) {
    $path = $videosDir . '/' . $file;
    $videoData[] = [
        'filename' => $file,
        'ctime' => filectime($path)
    ];
}
usort($videoData, function($a, $b) {
    return $b['ctime'] - $a['ctime'];
});
?>

<!DOCTYPE html>
<html lang="en">
<?php include './includes/head.php'; ?>

<body>
    <?php include './includes/navigation.php'; ?>
    <?php include './includes/header.php'; ?>
    <main>
        <section>
            <h2>Videos</h2>

            <?php if (!empty($videoData)): ?>
                <div class="videos-container">
                    <?php foreach ($videoData as $video): ?>
                        <div class="video-item">
                            <video controls>
                                <source src="media/videos/<?php echo htmlspecialchars($video['filename']); ?>" type="video/mp4">
                                Your browser does not support the video tag.
                            </video>
                            <p><?php echo pathinfo($video['filename'], PATHINFO_FILENAME); ?></p>
                            <div class="video-controls">
                                <button class="btn share-btn">Delen</button>
                                <button class="btn theatre-btn">Theatermodus</button>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php else: ?>
                <p>No videos found.</p>
            <?php endif; ?>

        </section>
    </main>

    <?php include './includes/footer.php'; ?>

    <script>
    document.addEventListener('DOMContentLoaded', function() {
        document.querySelectorAll('.share-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var videoItem = btn.closest('.video-item');
                var src = videoItem.querySelector('video source').src;
                if (navigator.share) {
                    navigator.share({ title: videoItem.querySelector('p').innerText, url: src })
                    .catch(function(error) { console.error('Error sharing', error); });
                } else if (navigator.clipboard) {
                    navigator.clipboard.writeText(src).then(function() {
                        alert('Videolink gekopieerd naar klembord');
                    }, function(err) {
                        alert('Kon link niet kopiëren: ' + err);
                    });
                } else {
                    prompt('Kopieer deze link:', src);
                }
            });
        });

        document.querySelectorAll('.theatre-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var videoItem = btn.closest('.video-item');
                var isActive = videoItem.classList.toggle('theatre-mode');
                btn.innerText = isActive ? 'Sluit theatermodus' : 'Theatermodus';
            });
        });
    });
    </script>
</body>
</html>