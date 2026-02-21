'''
This module defines the controls for the flight. 
'''
from pymavlink import mavutil
import time
import math


class Control:
    altitude_tolerance = 0.02  # meters
    arm_timout = 3
    
    def __init__(self):
        # Setup MAVLink connection
        print("Setting up MAVLink connection...")
        self.master = mavutil.mavlink_connection('udp:0.0.0.0:14550')
        self.master.wait_heartbeat()
        print(f"Connected to MAVLink! System ID: {self.master.target_system}, Component: {self.master.target_component}")
        
    def set_mode(self, mode):
        """Set the flight mode of the drone"""
        print(f"Setting mode to {mode}...")
        mode_id = self.master.mode_mapping()[mode]
        self.master.mav.set_mode_send(
            self.master.target_system,
            mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            mode_id
        )
        time.sleep(2)
        print(f"Mode set to {mode}.")
    
    def arm_motors(self):
        """Arm the drone motors"""
        print("Arming motors...")
        self.master.arducopter_arm()
        time.sleep(1)
        # Confirm armed
        count = 0
        while not self.is_armed() and count < self.arm_timout:
            print("Waiting for arming...")
            time.sleep(1)
            count += 1
        
        if self.is_armed():
            print("Motors armed!")
        else:
            print("force arming motors...")
            self.master.mav.command_long_send(
                self.master.target_system,
                self.master.target_component,
                mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
                0,
                1,      # arm
                21196,  # force-arm code for ArduPilot
                0, 0, 0, 0, 0
            )
            time.sleep(1)
            if self.is_armed():
                print("Motors armed after force-arm!")
            else:
                print("Failed to arm motors.")
            
    
    def is_armed(self):
        """Check if the drone is armed"""
        self.master.mav.request_data_stream_send(
            self.master.target_system,
            self.master.target_component,
            mavutil.mavlink.MAV_DATA_STREAM_ALL,
            1, 1
        )
        msg = self.master.recv_match(type='HEARTBEAT', blocking=True)
        return msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
    
    def get_current_yaw(self):
        """Get current yaw angle from the drone"""
        # Request attitude data
        self.master.mav.request_data_stream_send(
            self.master.target_system,
            self.master.target_component,
            mavutil.mavlink.MAV_DATA_STREAM_EXTRA1,
            1, 1
        )
        
        msg = self.master.recv_match(type='ATTITUDE', blocking=True, timeout=2)
        if msg:
            yaw_rad = msg.yaw
            yaw_deg = math.degrees(yaw_rad) % 360
            return yaw_deg
        return 0.0

    def takeoff(self, target_altitude):
        """Takeoff to a specified altitude"""
        print(f"Taking off to {target_altitude} meters...")
        self.master.mav.command_long_send(
            self.master.target_system,
            self.master.target_component,
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
            0,
            0, 0, 0, 0,
            0, 0,
            target_altitude
        )
        # Wait until target altitude is reached
        while True:
            msg = self.master.recv_match(type='GLOBAL_POSITION_INT', blocking=True)
            current_alt = msg.relative_alt / 1000.0  # Convert mm to meters
            print(f"Altitude: {current_alt:.1f}m / {target_altitude}m")
            if abs(current_alt - target_altitude) < self.altitude_tolerance:
                print(f"Reached target altitude of {target_altitude} meters!")
                break
            time.sleep(1)

    def turn_yaw(self, degrees):
        """
        Turn the drone by specified degrees (positive = right/clockwise)
        This just demonstrates a simple yaw turn using MAV_CMD_CONDITION_YAW
        """
        current_yaw = self.get_current_yaw()
        target_yaw = (current_yaw + degrees) % 360
        
        print(f"Turning {degrees}° (from {current_yaw:.1f}° to {target_yaw:.1f}°)")
        
        # Use MAV_CMD_CONDITION_YAW command for precise yaw control
        # This is the most reliable method for ArduPilot
        is_relative = 1  # 1 = relative to current heading, 0 = absolute
        direction = 1 if degrees > 0 else -1  # 1 = clockwise, -1 = counter-clockwise
        
        self.master.mav.command_long_send(
            self.master.target_system,
            self.master.target_component,
            mavutil.mavlink.MAV_CMD_CONDITION_YAW,
            0,
            abs(degrees),  # param1: target angle in degrees
            30.0,          # param2: yaw speed in deg/s
            direction,     # param3: direction (1=CW, -1=CCW)
            is_relative,   # param4: 0=absolute, 1=relative
            0, 0, 0
        )
        
        # Wait for turn to complete
        # Calculate expected turn time with some buffer
        turn_time = abs(degrees) / 30.0 + 1.0  # 30 deg/s + 1s buffer
        time.sleep(turn_time)
        
        # Verify turn
        final_yaw = self.get_current_yaw()
        print(f"Turn complete. Final yaw: {final_yaw:.1f}°")
        
        return final_yaw

    def land(self):
        """Land the drone"""
        print("Landing...")
        self.master.mav.command_long_send(
            self.master.target_system,
            self.master.target_component,
            mavutil.mavlink.MAV_CMD_NAV_LAND,
            0,
            0, 0, 0, 0,
            0, 0, 0
        )
        # Wait until disarmed
        while self.is_armed():
            print("Waiting for landing...")
            time.sleep(1)
        print("Landed and motors disarmed!")

    
    def move_with_velocity(self, vx, vy, vz, duration, dt=0.1):
        """Move the drone with specified velocities for a duration (in seconds)
        vx: forward/backward (positive = forward in drone's direction)
        vy: left/right (positive = right)
        vz: up/down (positive = down in NED frame)
        """
        end_time = time.time() + duration
        while time.time() < end_time:
            self.master.mav.set_position_target_local_ned_send(
                0,
                self.master.target_system,
                self.master.target_component,
                mavutil.mavlink.MAV_FRAME_BODY_OFFSET_NED,  # Changed to body frame
                0b0000111111000111,  # Use velocity components
                0, 0, 0,  # Position (not used)
                vx, vy, vz,  # Velocity
                0, 0, 0,  # Acceleration (not used)
                0, 0  # Yaw, Yaw rate (not used)
            )
            time.sleep(dt if dt < (end_time - time.time()) else (end_time - time.time()))