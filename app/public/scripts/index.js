const ws = new WebSocket(
  'ws://' + window.location.host + window.location.pathname
  + 'connect?token=' + token);

ws.onopen = function(event) {
  console.log('WebSocket connection established');
};

ws.onmessage = function(event) {
  let message = JSON.parse(event.data);
  let license_plate = message.license_plate;
  let policy_status = message.policy_status;
  let payment_status = message.payment_status;

  changePolicyStatus(license_plate, policy_status, payment_status);
};

ws.onerror = function(event) {
  console.error('WebSocket error:', event);
};

ws.onclose = function(event) {
  console.log('WebSocket connection closed');
};

function changePolicyStatus(licensePlate, policyStatus, paymentStatus) {
  const paymentStatusElement = document.querySelector(`#${licensePlate}-payment-status`);
  paymentStatusElement.innerText = paymentStatus;

  const policyStatusElement = document.querySelector(`#${licensePlate}-policy-status`);
  policyStatusElement.innerText = policyStatus;
}
