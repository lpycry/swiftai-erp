UPDATE outbound_orders
SET status = 'issued'
WHERE status = 'shipped';
