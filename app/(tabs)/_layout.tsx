import { Tabs } from 'expo-router';
import React from 'react';
import { FontAwesome5 } from '@expo/vector-icons'; // FontAwesome5 아이콘 (car-crash)

import { TabBarIcon } from '@/components/navigation/TabBarIcon';
import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';

export default function TabLayout() {
  const colorScheme = useColorScheme();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors[colorScheme ?? 'light'].tint,
        headerShown: false,
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'CAMERA', // 버튼 그림 아래 텍스트 Home에서 CAMERA로 변경
          tabBarIcon: ({ color, focused }) => (
            <TabBarIcon name={focused ? 'camera-reverse' : 'home-outline'} color={color} /> // 그림 home에서 camera-reverse로 변경
          ),
        }}
      />
      <Tabs.Screen
        name="explore"
        options={{
          title: 'HISTORY', // code slash에서 car-crash로 변경
          tabBarIcon: ({ color, focused }) => (
            <FontAwesome5 name={focused ? 'car-crash' : 'car-crash'} color={color} size={24} />
          ),
        }}
      />
    </Tabs>
  );
}
