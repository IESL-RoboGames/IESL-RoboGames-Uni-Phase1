'''
Camera interface to start the TCP camera thread and receive frames from the camera server.
'''

import socket
import struct
import threading
import time
import cv2
import numpy as np

class Camera:
    """Camera interface to start the TCP camera thread"""
    def __init__(self, host='127.0.0.1', port=5599):
        self.host = host
        self.port = port
        self.thread_stop_event = None
        self.camera_thread = None


    def start_thread(self, callback):
        """Start the TCP camera thread"""
        def camera_thread():
            if self.thread_stop_event is None:
                self.thread_stop_event = threading.Event()
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.connect((self.host, self.port))
                    print(f"Connected to camera at {self.host}:{self.port}")
                    while not self.thread_stop_event.is_set():
                        frame = self.get_frame(s)
                        if frame is not None:
                            callback(frame)
                        else:
                            print("Failed to receive frame")
                            break
        self.camera_thread = threading.Thread(target=camera_thread, daemon=True)
        self.camera_thread.start()

    def stop_thread(self):
        """Stop the TCP camera thread"""
        if self.thread_stop_event is not None:
            self.thread_stop_event.set()
            self.camera_thread.join()
            self.thread_stop_event = None
        cv2.destroyAllWindows()

    def get_frame(self, s):
        """Get the latest camera frame"""
        # 1. Read Header (4 bytes: Width, Height)
        header_data = self._recv_all(s, 4)
        if not header_data: return None
        width, height = struct.unpack("=HH", header_data)

        img_data = self._recv_all(s, width * height * 3)
        if not img_data: return None
        frame = np.frombuffer(img_data, dtype=np.uint8).reshape((height, width, 3))
        return frame


    def is_running(self):
        return self.thread_stop_event is not None and not self.thread_stop_event.is_set()

    def _recv_all(self, sock, n):
        """Helper to receive exactly n bytes from a TCP socket"""
        data = bytearray()
        while len(data) < n:
            packet = sock.recv(n - len(data))
            if not packet: return None
            data.extend(packet)
        return data
    
    def __del__(self):
        """Destructor to ensure threads are stopped and windows closed"""
        self.stop_thread()
        cv2.destroyAllWindows()