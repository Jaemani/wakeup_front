import { CameraView, CameraType, useCameraPermissions } from 'expo-camera';
import { SetStateAction, useEffect, useState } from 'react';
import { Button, StyleSheet, Text, TouchableOpacity, View, StatusBar, Image, Dimensions, Modal } from 'react-native';
import { Audio } from 'expo-av';
import * as Location from 'expo-location';
import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import FontAwesome5 from '@expo/vector-icons/FontAwesome5';
import FontAwesome from '@expo/vector-icons/FontAwesome'

const { width, height } = Dimensions.get('window'); 

export default function App() {
  const [facing, setFacing] = useState<CameraType>('back');
  const [permission, requestPermission] = useCameraPermissions();
  const [sound, setSound] = useState<Audio.Sound|null>(null); // Since you are initializing sound state as undefined (useState()), Typescript doesn't allow setting sound to any other type.
  const [location, setLocation] = useState<Location.LocationObject|null>(null);
  const [errorMsg, setErrorMsg] = useState<string|null>(null);
  // ON/OFF 상태 관리
  const [camStatus, setCamStatus] = useState('OFF');
  const [blink, setBlink] = useState(true);
  // pop up
  const [isSleepModalVisible, setSleepModalVisible] = useState(false);
  const [isDangerModalVisible, setDangerModalVisible] = useState(false);

  
  // 0.5초 간격으로 Blink
  useEffect(() => {
    const interval = setInterval(() => {
      setBlink(prev => !prev);
    }, 500);
    return () => clearInterval(interval);
  }, [blink]);

  // 상태 토글 함수 - OFF에서 ON으로 바꾸거나 그 반대로 상태를 전환
  function toggleOnOff() {
    setCamStatus((prev) => (prev === 'OFF' ? 'ON' : 'OFF'));
  }

  // pop up status
  const toggleSleepModal = () => {
    setSleepModalVisible(!isSleepModalVisible);
  };

  const toggleDangerModal = () => {
    setDangerModalVisible(!isDangerModalVisible);
  };

  useEffect(() => {
    (async () => {
      
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setErrorMsg('Permission to access location was denied');
        return;
      }

      let location = await Location.getCurrentPositionAsync({});
      setLocation(location);
    })();
  }, []);

  let text = 'Waiting..';
  if (errorMsg) {
    text = errorMsg;
  } else if (location) {
    text = JSON.stringify(location);
    console.log(text)
  }



  async function playSound() {
    console.log('Loading Sound');
    const { sound } = await Audio.Sound.createAsync(require('../../assets/notification.mp3')
    );
    setSound(sound);

    console.log('Playing Sound');
    await sound.playAsync();
  }
  useEffect(() => {
    Audio.setAudioModeAsync({
      playsInSilentModeIOS: true,
    }); // ios silentMode
    return sound
      ? () => {
          console.log('Unloading Sound');
          //sound.unloadAsync();
        }
      : undefined;
  }, [sound]);

  if (!permission) {
    // Camera permissions are still loading.
    return <View />;
  }

  if (!permission.granted) {
    // Camera permissions are not granted yet.
    return (
      <View style={styles.container}>
        <Text style={styles.message}>We need your permission to show the camera</Text>
        <Button onPress={requestPermission} title="grant permission" />
      </View>
    );
  }


  function toggleCameraFacing() {
    setFacing(current => (current === 'back' ? 'front' : 'back'));
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" />  
      <View style={styles.statusBar}>
        <View style={styles.statusContent}>
          <Text style={[styles.statusText, { opacity: blink ? 1 : 0 }]}>
            {camStatus}
          </Text>
          {camStatus === 'ON' ? (
            <Image style={[styles.icon, { opacity: blink ? 1 : 0 }]} source={require('../../assets/images/Green_Dot.png')} />
          ) : (
            <Image style={[styles.icon, { opacity: blink ? 1 : 0 }]} source={require('../../assets/images/Red_Dot.png')} />
          )}
         </View>   
      </View>
      <Button title="Toggle ON/OFF" onPress={toggleOnOff}/>
      <Text style={styles.text}>{text}</Text>
      <Button title="Play Sound" onPress={playSound} />
      <CameraView style={styles.camera} facing={facing}>
    
      <Button title="졸음 감지" onPress={toggleSleepModal} />
      <Button title="사고다발구간에서 졸음 감지" onPress={toggleDangerModal} />
      <Modal visible={isSleepModalVisible} transparent={true} animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.iconContainer}>
              {/* FontAwesome 아이콘 */}
              <FontAwesome name="warning" size={50} color="#FFD700" />
            </View>
            <View style={styles.textContainer}>
              <Text style={styles.modalWarningText1}>WARNING</Text>
              <Text style={styles.modalDetectText}>졸음 감지</Text>
            </View>
            <Button title="닫기" onPress={toggleSleepModal} />
          </View>
        </View>
      </Modal>

      {/* 사고다발구간에서 졸음 감지 모달 */}
      <Modal visible={isDangerModalVisible} transparent={true} animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.iconContainer}>
              {/* FontAwesome 아이콘 */}
              <FontAwesome name="warning" size={50} color="red" />
            </View>
            <View style={styles.textContainer}>
              <Text style={styles.modalWarningText2}>DANGER</Text>
              <Text style={styles.modalDetectText}>사고다발구간에서 졸음 감지</Text>
            </View>
            <Button title="닫기" onPress={toggleDangerModal} />
          </View>
        </View>
      </Modal>
        <View style={styles.buttonContainer}>
          <TouchableOpacity style={styles.button} onPress={toggleCameraFacing}>
            <Text style={styles.text}>Flip Camera</Text>
          </TouchableOpacity>
        </View>
      </CameraView>
    </View>
  );

}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
  },
  message: {
    textAlign: 'center',
    paddingBottom: 10,
  },
  camera: {
    flex: 1,
  },
  buttonContainer: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: 'transparent',
    margin: 64,
  },
  button: {
    flex: 1,
    alignSelf: 'flex-end',
    alignItems: 'center',
  },
  text: {
    fontSize: 24,
    fontWeight: 'bold',
    color: 'white',
  },
  statusBar: { // status bar
    height: height * 0.035,
    marginTop: StatusBar.currentHeight || 0,
  },
  statusContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusText: {
    textAlign: "left",
    marginLeft: width * 0.045,
    marginRight: width * 0.01,
    fontSize: width * 0.05,
    fontWeight: 'bold',
    color: 'red',
  },
  icon: {
    width: width * 0.03,
    height: width * 0.03,
  },
  modalWarningText1: { // modal
    fontSize: 30,
    fontWeight: 'bold',
    color: '#FFD700',
    marginBottom: 10,
  },
  modalWarningText2: {
    fontSize: 30,
    fontWeight: 'bold',
    color: 'red',
    marginBottom: 10,
  },
  modalButton: {
    backgroundColor: '#FF6347',
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 5,
    marginTop: 20,
  },
  modalButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
  modalDetectText: {
    fontSize: 20,
    color: '#000000',
  },
  modalOverlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: 'white',
    padding: 20,
    borderRadius: 10,
    alignItems: 'center',
    width: 400,
    height: 200, // 높이를 충분히 설정
    justifyContent: 'center',
  },
  iconContainer: {
    position: 'absolute', // 아이콘을 텍스트와 별도로 배치
    left: 30,
    top: '60%', // 상하 중앙 정렬
    transform: [{ translateY: -20 }], // 상하 중앙 정렬을 정확히 맞추기 위해 변환
  },
  textContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
});
