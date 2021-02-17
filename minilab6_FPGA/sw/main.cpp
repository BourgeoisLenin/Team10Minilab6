// Copyright (c) 2020 University of Florida
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Greg Stitt
// University of Florida
//
// This example demonstrates an AFU wrapper class built around the OPAE API 
// to do the following:
// 1) request an FPGA with a specific AFU
// 2) read and write from a memory-mapped register in the FPGA 

#include <cstdlib>
#include <iostream>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <climits>
#include <unistd.h>

#include <opae/utils.h>

#include "AFU.h"

using namespace std;

// Auto-generated by OPAE's afu_json_mgr script
#include "afu_json_info.h"

//=========================================================
// Define the address of the memory-mapped register according the address
// that was used in the RTL code.
//
// NOTE: Ideally this could be generated with a .json file just like the
// AFU_ACCEL_UUID. Without auto-generation, you must manually ensure that
// the addresses match between the RTL code and software code.
//=========================================================
#define USER_REG_ADDR 0x0020

#define PANIC(E_C, MSG) if(!(E_C)) { fprintf(stderr, MSG); exit(1);}

typedef int8_t AB_TYPE;
typedef int16_t C_TYPE;
#define DIM 8
#define DIM_FULL 16
#define MAX_VAL _UI16_MAX
#define DEBUG true

AB_TYPE A_vals[DIM_FULL][DIM_FULL];
AB_TYPE B_vals[DIM_FULL][DIM_FULL];
C_TYPE output[DIM_FULL][DIM_FULL];
C_TYPE output_reference[DIM_FULL][DIM_FULL];

//NEW
AB_TYPE A_row[DIM];
AB_TYPE B_row[DIM];
C_TYPE output_row[DIM];
C_TYPE c_zero[8] = {0,0,0,0,0,0,0,0};

// Reflect Endian
template<int width, class BT> BT ref_end(BT in)
{
	int bytes = width / 8;
	BT src = in;
	BT ret = 0;
	char* wh = reinterpret_cast<char*>(&src);
	char* dst = reinterpret_cast<char*>(&ret);
	for(int itr = 0; itr < bytes; ++itr)
	{
		dst[itr] = wh[bytes - 1 - itr];
	}

	if(DEBUG) printf("ref_end: %lx -> %lx\n", src, ret);

	return ret;
}

template<int base_addr> void send_row_X(uint16_t row, AB_TYPE* vals, AFU& afu)
{
	uint64_t real_addr = base_addr + row * 8;
	uint64_t data_word = 0;

	// Pack each of the values into single 64-bit word
	for(int t = 0; t < DIM; ++t)
	{
		data_word |= ((static_cast<uint64_t>(vals[t]) & 0x0FF) << (t * sizeof(AB_TYPE)*8));
	}


	uint64_t data_word_cal = data_word;// ref_end<64, uint64_t>(data_word);

	if(DEBUG) printf("data word val, addr: %lx | %lx\n", data_word_cal, real_addr);

	// Do MMIO Write of Data Word
	afu.write(real_addr, data_word_cal);
}

void send_row_A(uint16_t row, AB_TYPE * vals, AFU& afu) { send_row_X<0x100>(row, vals, afu); }
void send_row_B(uint16_t row, AB_TYPE * vals, AFU& afu) { send_row_X<0x200>(row, vals, afu); }

void send_row_C(uint16_t row, C_TYPE* vals, AFU& afu)
{ // can easily genericize send_row_X further. TODO: do that

	uint64_t wds[2] = {0};

	uint64_t base_addr = 0x300;
	uint64_t lw_addr = base_addr + row * 0x10;
	uint64_t hw_addr = lw_addr + 0x8;

	// Read the two words;
	unsigned bitind = 0;


	// Partition the words into their respective rows
	for(ptrdiff_t ind = 0; ind < DIM; ++ind)
	{
		uint64_t base_mask = 0x0FFFF;

		// TODO: unhardcode 16-bit
		bitind = (ind / 4);
		uint64_t shift_count = (ind * 16) % 64;

		// Mask and store
		wds[bitind] |= ((vals[ind] & (base_mask)) << shift_count);
	}

	if(DEBUG)
		fprintf(stdout, "CWRITE: low word, high word, address %lx | %lx @%lx @%lx\n", wds[0], wds[1], lw_addr, hw_addr);

	afu.write(lw_addr, wds[0]);
	afu.write(hw_addr, wds[1]);
}

void unpack_from_C(uint16_t row, C_TYPE * vals, AFU& afu)
{
	uint64_t wds[2] = {0};

	uint64_t base_addr = 0x300;
	uint64_t lw_addr = base_addr + row * 0x10;
	uint64_t hw_addr = lw_addr + 0x8;

	// Read the two words;
	wds[0] = afu.read(lw_addr);
	wds[1] = afu.read(hw_addr);
	unsigned bitind = 0;

//	wds[0] = ref_end<64, uint64_t>(wds[0]);
//	wds[1] = ref_end<64, uint64_t>(wds[1]);

	if(DEBUG)
		fprintf(stdout, "low word, high word, address %lx | %lx @%lx @%lx\n", wds[0], wds[1], lw_addr, hw_addr);

	// Partition the words into their respective rows
	for(ptrdiff_t ind = 0; ind < DIM; ++ind)
	{
		uint64_t base_mask = 0x0FFFF;

		// TODO: unhardcode 16-bit
		bitind = (ind / 4);
		uint64_t shift_count = (ind * 16) % 64;

		// Mask and store
		vals[ind] = ((wds[bitind] & (base_mask << shift_count)) >> shift_count);
	}
}

int main(int argc, char *argv[]) {

  try {
    // Create an AFU object to provide basic services for the FPGA. The 
    // constructor searchers available FPGAs for one with an AFU with the
    // the specified ID
    AFU afu(AFU_ACCEL_UUID);

        // Seed random generator with "now"
        timeval tv;
	gettimeofday(&tv, nullptr);
	srand(tv.tv_usec);

	fprintf(stdout, "FULL SYSTEM TEST\n---------------\n");
	fprintf(stdout, "Populating A and B...\n");
	// Generate A vals, B vals.
	for(int y_ind = 0; y_ind < DIM_FULL; ++y_ind)
	{
		for(int x_ind = 0; x_ind < DIM_FULL; ++x_ind)
		{
			A_vals[y_ind][x_ind] = static_cast<int8_t>(rand() % 255);
			B_vals[y_ind][x_ind] = static_cast<int8_t>(rand() % 255);
		}
	}


	fprintf(stdout, "Calculating reference values of C...\n");
	// Calculate reference C values.
	for(int y_ind = 0; y_ind < DIM_FULL; ++y_ind)
	{
		for(int x_ind = 0; x_ind < DIM_FULL; ++x_ind)
		{
			// Calculate C
			output_reference[y_ind][x_ind] = 0;

			for(ptrdiff_t wh = 0; wh < DIM; ++wh)
			{
				output_reference[y_ind][x_ind] += A_vals[y_ind][wh] * B_vals[wh][x_ind];
			}
		}
	}

	for(ptrdiff_t BLK_r = 0; BLK_r<DIM_FULL/DIM;BLK_r++){
		for(ptrdiff_t BLK_c = 0; BLK_c<DIM_FULL/DIM;BLK_c++){
			// Now try it with the AFU.
			//fprintf(stdout, "Block row:%td, Block col:%td\n",BLK_r,BLK_c);
			for(ptrdiff_t c_r = 0; c_r < DIM; ++c_r)
			{
				for(int cnt = 0; cnt < DIM; cnt++){
					output_row[cnt] = output[BLK_r*DIM+c_r][BLK_c*DIM+cnt];
				}
				send_row_C(c_r,output_row,afu);
			}

			// Write each value of A down.
			fprintf(stdout, "Loading A into AFU...\n");
			for(ptrdiff_t k = 0; k<DIM_FULL/DIM;k++){
				for(ptrdiff_t a_r = 0; a_r < DIM; ++a_r)
				{
					for(int cnt = 0; cnt < DIM; cnt++){
						A_row[cnt] = A_vals[BLK_r*DIM+a_r][k*DIM+a_r];
					}
					//fprintf(stdout,"A_row here! %hx \n",A_row[0]);
					send_row_A(a_r, A_row, afu);
				}
			}

			// Push each value of B.
			fprintf(stdout, "Loading B into AFU...\n");
			for(ptrdiff_t k = 0; k<DIM_FULL/DIM;k++){
				for(ptrdiff_t b_r = 0; b_r < DIM; ++b_r)
				{
					for(int cnt = 0; cnt < DIM; cnt++){
						B_row[cnt] = B_vals[k*DIM+b_r][BLK_c*DIM];
					}
					//fprintf(stdout,"B_row here! %hx \n",B_row[0]);
					send_row_B(b_r, B_row, afu);
				}
			}
			// Calculate
			fprintf(stdout, "Performing Calculation...\n");
			afu.write(0x0400, 100);
			// Do we have to sleep?
		//	usleep(1000*1000);

			// Read Values.
			fprintf(stdout, "Reading Output from C...\n");

			for(ptrdiff_t c_r = 0; c_r < DIM; ++c_r)
			{
				unpack_from_C(c_r, output_row, afu);
				//fprintf(stdout,"output_row here! %hx \n",output_row[0]);
				for(int cnt = 0; cnt < DIM; cnt++){
					output[BLK_r*DIM+c_r][BLK_c*DIM+cnt] = output_row[cnt];
				}
				//fprintf(stdout,"output here! %hx \n",output[BLK_r*8+c_r][BLK_c]);

			}

		}
	}

	// Compare.
	fprintf(stdout, "Calculation finished. Testing values...\n");
	for(int r = 0; r < DIM_FULL; ++r)
	{
		for(int c = 0; c < DIM_FULL; ++c)
		{
			fprintf(stdout, "row: %d, col: %d | got: %hx, expected %hx", r, c, output[r][c], output_reference[r][c]);
			fflush(stdout);
			assert(output[r][c] == output_reference[r][c]);
			fprintf(stdout, " [OK]\n");
		}
	}

	fprintf(stdout, "All tests passed. No errors detected.\n");

	return 0;    
  }
  // Exception handling for all the runtime errors that can occur within 
  // the AFU wrapper class.
  catch (const fpga_result& e) {    
    
    // Provide more meaningful error messages for each exception.
    if (e == FPGA_BUSY) {
      cerr << "ERROR: All FPGAs busy." << endl;
    }
    else if (e == FPGA_NOT_FOUND) { 
      cerr << "ERROR: FPGA with accelerator " << AFU_ACCEL_UUID 
	   << " not found." << endl;
    }
    else {
      // Print the default error string for the remaining fpga_result types.
      cerr << "ERROR: " << fpgaErrStr(e) << endl;    
    }
  }
  catch (const runtime_error& e) {    
    cerr << e.what() << endl;
  }
  catch (const opae::fpga::types::no_driver& e) {
    cerr << "ERROR: No FPGA driver found." << endl;
  }

  return EXIT_FAILURE;
}
