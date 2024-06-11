# Matrix Vector Multiplier using UART Communication

This project implements a Matrix Vector Multiplier (MVM) on an FPGA, which is commonly used in convolutional neural networks (CNNs) for deep learning applications. By improving the efficiency of MVM, response time can be reduced, accelerating procedures with hardware acceleration.

## Overview

The project utilizes UART (Universal Asynchronous Receiver-Transmitter) as the data communication protocol to transfer data from a PC to the FPGA in serial communication. Subsequently, the UART_RX module converts this serial data into a parallel AXI (Advanced eXtensible Interface) stream and forwards it to the MatVec Mul module through the AXI stream.

In the MatVec Mul module, the multiplication operation is performed. A Skid Buffer module is employed to control the flow without congestion, ensuring efficient data handling. The processed data is then transmitted to the TX module and converted back into a serial stream. Finally, the results can be observed on a PC.

## Purpose

The purpose of this project is to implement a matrix-vector multiplier for FPGA. By utilizing efficient data communication protocols and hardware modules, the efficiency of the MVM operation can be significantly improved, thereby reducing response time and accelerating the overall procedure.

## Simulation Results

[Insert simulation results here]

## License

[Insert license information here]

