'''
This contains the opencv, line following stuff. This will make the decisions for the robot based on what the camera sees and 
send commands to the controller.
'''
t
import cv2
import numpy as np
from control import Control
import time
from sensor import Camera

class Brain:
    def __init__(self):
        self.control = Control()
        self.camera = Camera()

    def process_frame(self, frame):
        """
        Process the camera frame to detect lines and make decisions.
        use Camera class to get the frames.
        """
        
        pass
        

        
    
    def line_follow(self):
        """
        Main line following logic.
        Consider PID control for smoother movement.
        Use the control class to send movement commands based on the detected line position.
        """

        pass

    def start(self):
        """Start the processing"""
        self.camera.start_thread(self.process_frame)
        self.control.set_mode('GUIDED')
        self.control.arm_motors()
        self.control.takeoff(0.27)
        # Add the rest as needed, like line following loop, landing logic, etc.
    
    def __del__(self):
        """Destructor to ensure threads are stopped"""
        self.camera.stop_thread()


if __name__ == "__main__":
    brain = Brain()
    try:
        brain.start()
    except KeyboardInterrupt:
        print("Stopping brain...")
    finally:
        del brain