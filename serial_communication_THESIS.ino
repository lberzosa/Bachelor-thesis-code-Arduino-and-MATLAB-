
const int emgPin = A0;
const int sampleRate = 500;
const int delayTime = 1000 / sampleRate;

const int numSamples = 5;
int readings[numSamples];
int indexReadings = 0;
long sum = 0;
int average = 0;

void setup() {
  Serial.begin(115200);
  pinMode(emgPin, INPUT);
  
  for (int i = 0; i < numSamples; i++) {
    readings[i] = 0;
  }
  
  Serial.println("START");
}

void loop() {
  
  int actualReadings = analogRead(emgPin);
  
  sum = sum - readings[indexReadings];
  readings[indexReadings] = actualReadings;
  sum = sum + readings[indexReadings];
  indexReadings = (indexReadings + 1) % numSamples;
  
  average = sum / numSamples;
  
  Serial.println(average);
  
  delay(delayTime);
}
