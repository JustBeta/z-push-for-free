<?php
// 1. Lire la requête entrante
$rawInput = file_get_contents('php://input');
$headers = getallheaders();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : null;

// 2. Modifier l’adresse e-mail dans le XML
$local_domain = 'jobar.fr';
$provider_domain = 'free.fr';
$rawInput = preg_replace(
    '/(<EMailAddress>[^@<]+)@' . preg_quote($local_domain, '/') . '(<\/EMailAddress>)/i',
    '${1}@' . $provider_domain . '${2}',
    $rawInput
);

if (!isset($_SERVER['PHP_AUTH_USER'])) {
    header('WWW-Authenticate: Basic realm="Z-Push Autodiscover"');
    header('HTTP/1.0 401 Unauthorized');
    echo "Authentication required";
    exit;
}

// 3. Modifier les identifiants dans l’en-tête Authorization
if ($authHeader && preg_match('/Basic\s+([A-Za-z0-9+\/=]+)/', $authHeader, $matches)) {
    $decoded = base64_decode($matches[1]);
    if (strpos($decoded, "@$local_domain") !== false) {
        $decoded = preg_replace('/@' . preg_quote($local_domain, '/') . '$/i', "@$provider_domain", $decoded);
        $authHeader = 'Basic ' . base64_encode($decoded);
    }
}

// 4. Construire la requête vers le vrai autodiscover.php
$opts = [
    'http' => [
        'method' => 'POST',
        'header' => "Content-Type: text/xml\r\n" .
                    ($authHeader ? "Authorization: $authHeader\r\n" : ''),
        'content' => $rawInput,
        'ignore_errors' => true
    ]
];
$context = stream_context_create($opts);
$response = file_get_contents('https://' . $_SERVER['HTTP_HOST'] . '/index.php', false, $context);

// 5. Renvoyer la réponse au client
http_response_code(http_response_code());
foreach ($http_response_header as $hdr) {
    if (stripos($hdr, 'Content-Type:') === 0) {
        header($hdr);
    }
}
echo $response;
