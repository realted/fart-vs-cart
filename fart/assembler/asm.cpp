/*
Simple assembler for the multicycle processor implementation.
Produces a MIF file that can be used to initialize the memory.
In addition to the 10 instructions, it supports the org directive
and the db directive. It also supports labels. It uses
16-bit memory words and the new 16-bit instruction encodings. The db directive
accepts -32768..65535; negative data uses 16-bit two's complement.
Memory depth is controlled by MEM_SIZE.

Change R.Willenberg - Oct 2012: Also produces a *.mem file for ModelSim simulation purposes
Change F.Martin del Campo - Nov 2015: Added cstring library and changed b and e variables to size_t. This version works with the cywin included with altera 15.0
Change P.Poolad updated with new instruction codes for nop/stop and vector instrucitons, debuged db instruction
*/

#include <iostream>
#include <fstream>
#include <cstring>
#include <string>
#include <cstdlib>
#include <map>
#include <cstdio>
#include <vector>
#include <cstdint>
#include <cerrno>
#include <climits>

using namespace std;

#define MEM_SIZE 256
#define NUM_KEYWORDS 25

typedef struct instruction
{
	int addr;
	int line_number;
	string keyword;
	string operands;
} instr;

bool isKeyword(string str)
{
	string keywords[NUM_KEYWORDS] = {"load", "store", "add", "sub", "nand", "ori",
						  "shift", "shiftl", "shiftr", "bz", "bnz", "bpz",
					 "org", "db", "stop", "nop", "vload", "vstore", "vadd", "vsub", "vmul", "vcmplt", "vcmpgt", "vcmpeq", "vcmclr"};

	for (int i = 0; i < NUM_KEYWORDS; i++)
	{
		if (str == keywords[i])
			return true;
	}

	return false;
}

bool isNumber(string str)
{
	for (unsigned int i = 0; i < str.length(); i++)
	{
		if (i == 0)
		{
			if ((str[i] < '0' || str[i] > '9') && str[0] != '-')
				return false;
		}
		else if (str[i] < '0' || str[i] > '9')
			return false;
	}

	return true;
}

bool isHex(string str)
{
	for (unsigned int i = 0; i < str.length(); i++)
	{
		str[i] = toupper(str[i]);
		if ( (str[i] < '0' || str[i] > '9') && (str[i] < 'A' || str[i] > 'F') )
			return false;
	}

	return true;
}

bool isBinary(string str)
{
	for (unsigned int i = 0; i < str.length(); i++)
	{
		if (str[i] != '0' && str[i] != '1')
			return false;
	}

	return true;
}

bool isOctal(string str)
{
	for (unsigned int i = 0; i < str.length(); i++)
	{
		if (str[i] < '0' || str[i] > '7')
			return false;
	}

	return true;
}

bool labelExists (map <string, int>& labels, string label)
{
	return (labels.find(label) != labels.end());
}

// Scalar registers are k0..k3; vector registers are v0..v7 (x aliases).
bool registerIndex(const string& name, bool vector_reg, int& index)
{
    if (name.size() != 2 || name[1] < '0' || name[1] > (vector_reg ? '7' : '3')) return false;
    if (vector_reg ? (name[0] != 'v' && name[0] != 'x') : name[0] != 'k')
        return false;
    index = name[1] - '0';
    return true;
}

bool extractOperands(string ops, int& op1, int& op2,
                     bool load_store = false, bool vector_reg = false)
{
    const size_t comma = ops.find(',');
    if (comma == string::npos) return false;
    string first = ops.substr(0, comma), second = ops.substr(comma + 1);
    if (!registerIndex(first, vector_reg, op1)) return false;
    if (load_store) {
        if (second.size() != 4 || second.front() != '(' || second.back() != ')')
            return false;
        return registerIndex(second.substr(1, 2), false, op2);
    }
    return registerIndex(second, vector_reg, op2);
}

int processNumber(string str)
{
    if (str.empty()) throw "parse error";
    int base = 10;
    if (str[0] == '$') { base = 16; str = str.substr(1); }
    else if (str[0] == '%') { base = 2; str = str.substr(1); }
    else if (str[0] == '0' && str.length() > 1) { base = 8; }
    if (str.empty()) throw "parse error";
    char* end = NULL;
    errno = 0;
    long num = strtol(str.c_str(), &end, base);
    if (end == str.c_str() || *end != '\0' || errno == ERANGE ||
        num < INT_MIN || num > INT_MAX)
        throw "number out of range or invalid";
    return static_cast<int>(num);
}

int main(int argc, char* argv[])
{
	string line = " ";
	string outfilename;
	std::uint16_t mem[MEM_SIZE];
    bool occupied[MEM_SIZE] = {};
	int line_count = 0;
	unsigned int cur_address = 0;
	map <string, int> labels;
	vector <instr> instructions;
	

	if (argc < 2 || argc > 3)
	{
		cerr << "Usage: asm assembly_file [mif_file]" << endl;
		exit(1);
	}

	ifstream infile(argv[1], ios::in);

	if (infile.fail())
	{
		cerr << "Error: cannot open the input file.";
		exit(1);
	}

	ofstream outfile;	
	ofstream outfilesim;	

	if (argc == 2)
		outfilename = "data.mif";
	else if (argc == 3)
		outfilename = argv[2];
	
	// init memory to all zeros
	for (int i = 0; i < MEM_SIZE; i++)
		mem[i] = 0;

	while (!infile.eof())
	{
		std::getline(infile, line);
		if (line.length() > 0 && line[line.length()-1] == '\r')
			line.resize(line.length() - 1);
		string col1, col2, col3;
		size_t b, e;

		line_count++;

		try
		{
			// is line empty or is it a comment?
			b = line.find_first_not_of(" \t", 0);
			
			if (b == string::npos || line[b] == ';' || line.length() == 1)
				continue;

			if (line[0] == ' ' || line[0] == '\t')
			{
				col1 = "";
			}
			else
			{
				e = line.find_first_of(" \t", 0);
				b = line.find_first_not_of(" \t", e);
			
				if (e == string::npos || b == string::npos)
					throw "parse error";
			
				col1 = line.substr(0, e);
			}

			e = line.find_first_of(" \t", b);

			if (e == string::npos) {
			  col2 = line.substr(b);
			  if (col2 != "stop" && col2 != "nop" && col2 != "vcmclr")
			    throw "parse error";
			  
			}
			else col2 = line.substr(b, e-b);

			if (col2 != "stop" && col2 != "nop" && col2 != "vcmclr") 
			  {
			    b = line.find_first_not_of(" \t", e);
			
			    if (e == string::npos)
			      throw "parse error";

			    e = line.find_first_of(" \t;", b);

			    if (e == string::npos)
			      col3 = line.substr(b);
			    else 
			      {
				if (line[e] != ';')
				  {
				    size_t tmp_pos = line.find_first_not_of(" \t", e);
				    if (tmp_pos != string::npos && line[tmp_pos] != ';')
				      throw "parse error";
				  }

				col3 = line.substr(b, e-b);
			      }
			  }
            if (col2 == "stop" || col2 == "nop" || col2 == "vcmclr") {
                const size_t tail = (e == string::npos) ? string::npos : line.find_first_not_of(" \t", e);
                if (tail != string::npos && line[tail] != ';')
                    throw "instruction takes no operands";
            }
			if (!isKeyword(col2))
			{
				cerr << "Error: line " << line_count << ", unrecognized term '" << col2 << "'." << endl;
				exit(1);
			}

			if (col2 == "org")
			{	
				int addr = processNumber(col3);

				if (addr < 0 || addr > MEM_SIZE - 1)
				{
					cerr << "Error: line " << line_count << ", address out of range." << endl;
					exit(1);
				}
				
				cur_address = addr;

				if (col1 != "")
				{
					if (labelExists(labels, col1))
					{
						cerr << "Error: line " << line_count << ", duplicate declaration of '" << col1 << "'." << endl;
						exit(1);
					}
					else
						labels[col1] = cur_address;
				}
				continue;
			}

			if (col1 != "")
			{
				if (labelExists(labels, col1))
				{
					cerr << "Error: line " << line_count << ", duplicate declaration of '" << col1 << "'." << endl;
					exit(1);
				}
				else
					labels[col1] = cur_address;
			}

			instr op;
			op.addr = cur_address;
			op.line_number = line_count;
			op.keyword = col2;
			op.operands = col3;
			instructions.push_back(op);

			cur_address++;
		}
		catch (const char* reason)
		{
			cerr << "Error: line " << line_count << ": " << reason << "." << endl;
			exit(1);
		}
	}

	infile.close();

	for (unsigned int i = 0; i < instructions.size(); i++)
	{
		try
		{
			cur_address = instructions[i].addr;
			line_count = instructions[i].line_number;
			string col2 = instructions[i].keyword;
			string col3 = instructions[i].operands;

			if (cur_address > MEM_SIZE - 1)
			{
				cerr << "Error: line " << line_count << ", location of data or instruction overruns maximum address space." << endl;
				exit(1);
			}

			int op1, op2;
			int encoding;

			if (col2 == "db")
			{
				int c_encoding;
				// single character?
				if (col3.length() == 3 && col3[0] == '\'' && col3[2] == '\'')
					c_encoding = static_cast<unsigned char>(col3[1]);
				else
				{
					c_encoding = processNumber(col3);
					if (c_encoding < -32768 || c_encoding > 65535)
					{
						cerr << "Error: line " << line_count << ", db value must be between -32768 and 65535." << endl;
						exit(1);
					}
				}
				encoding = (int) c_encoding;
			}
            else if (col2 == "load" || col2 == "store" || col2 == "add" ||
                     col2 == "sub" || col2 == "nand" || col2 == "vload" ||
                     col2 == "vstore" || col2 == "vadd" || col2 == "vsub" ||
                     col2 == "vmul" || col2 == "vcmplt" || col2 == "vcmpgt" || col2 == "vcmpeq")
            {
                const bool vector_reg = col2[0] == 'v';
                const bool memory_op = col2 == "load" || col2 == "store" ||
                                       col2 == "vload" || col2 == "vstore";
                if (!extractOperands(col3, op1, op2, memory_op, vector_reg))
                    throw "invalid register operands";
                const map<string, int> opcodes = {
                    {"load", 0x00}, {"store", 0x02}, {"add", 0x04},
                    {"sub", 0x06}, {"nand", 0x08}, {"vload", 0x21},
                    {"vstore", 0x22}, {"vadd", 0x24}, {"vsub", 0x25},
                    {"vmul", 0x26}, {"vcmplt", 0x28}, {"vcmpgt", 0x29}, {"vcmpeq", 0x2A}
                };
                encoding = vector_reg
                    ? ((op1 << 13) | (op2 << 10) | (opcodes.at(col2) << 4))
                    : ((op1 << 14) | (op2 << 12) | (opcodes.at(col2) << 6));
            }
			else if (col2 == "ori")
			{
				int imm13 = processNumber(col3);
				
				if (imm13 < 0 || imm13 > 8191)
				{
					cerr << "Error: line " << line_count << ", number too large to fit in 13 bits (or is negative)." << endl;
					exit(1);
				}

				encoding = imm13;
				encoding <<= 3;
				encoding |= 7;
			}
			else if (col2 == "shift" || col2 == "shiftl" || col2 == "shiftr")
			{
				size_t comma_pos = col3.find_first_of(",");
				if (comma_pos == string::npos || comma_pos == 0 || comma_pos == col3.length()-1)
					throw "parse error";
				else
				{
					string sop1 = col3.substr(0,comma_pos);
					string sop2 = col3.substr(comma_pos+1);
					if (sop1 != "k0" && sop1 != "k1" && sop1 != "k2" && sop1 != "k3")
						throw "parse error";

					int imm11 = processNumber(sop2);
					
					if (col2 == "shiftl" || col2 == "shiftr")
					{
						if (imm11 < 0 || imm11 > 3)
						{
							cerr << "Error: line " << line_count << ", shiftl and shiftr can only accept parameters between 0 and 3." << endl;
							exit(1);
						}

						if (col2 == "shiftl")
							imm11 |= 4; // Direction bit 2: 1=left; bits 1:0=count.
					}	
					else if (imm11 < 0 || imm11 > 7)
					{
						cerr << "Error: line " << line_count << ", raw SHIFT must be 0..7; upper eight immediate bits are reserved." << endl;
						exit(1);
					}

					encoding = 0;
					encoding = (sop1[1] - '0') << 14;
					encoding += imm11 << 3;
					encoding |= 3;
				}
			}
			else if (col2 == "bz" || col2 == "bnz" || col2 == "bpz")
			{
				int imm12;
				if (labelExists(labels, col3))
				{
					int lbl_address = labels[col3];
					imm12 = lbl_address - static_cast<int>(cur_address) - 1;
				}
				else
					imm12 = processNumber(col3);
				
				if (imm12 < -2048 || imm12 > 2047)
				{
					cerr << "Error: line " << line_count << ", number cannot fit in 12 bits." << endl;
					exit(1);
				}

				encoding = (imm12 & 0xFFF) << 4;

				if (col2 == "bz")
					encoding |= 5;
				else if (col2 == "bnz")
					encoding |= 9;
				else
					encoding |= 13;
			}
            else if (col2 == "vcmclr")
            {
                encoding = 0xFEF0; // 111 111 101111 0000: enable all lanes.
            }
			else if (col2 == "stop")
			{
			    encoding = 0x01;
			}
			else if (col2 == "nop")
			  {
			    encoding = 0x8001;
			  }

			
			if (occupied[cur_address]) throw "overlapping org/data address";
            occupied[cur_address] = true;
            mem[cur_address] = static_cast<std::uint16_t>(encoding);
		}
		catch (const char* reason)
		{
			cerr << "Error: line " << line_count << ": " << reason << "." << endl;
			exit(1);
		}
	}

    outfile.open(outfilename, ios::out);
    if (!outfile) { cerr << "Cannot open output file." << endl; return 1; }
    outfilesim.open((string(outfilename) + ".mem").c_str(), ios::out);
    if (!outfilesim) { cerr << "Cannot open simulation output file." << endl; return 1; }

	// write output file
	outfile << "DEPTH = " << MEM_SIZE << ";" << endl;
	outfile << "WIDTH = 16;" << endl;
	outfile << "ADDRESS_RADIX = HEX;" << endl;
	outfile << "DATA_RADIX = HEX;" << endl;
	outfile << "CONTENT" << endl;
	outfile << "BEGIN" << endl << endl;

	for (int i = 0; i < MEM_SIZE; i++)
	{
		char str[10];
		sprintf(str, "%02X", static_cast<unsigned int>(i));
		outfile << str << " : ";

		sprintf(str, "%04X", static_cast<unsigned int>(mem[i]));

		outfile << str << ";" << endl;
	}

	outfile << endl << "END;" << endl;

	outfile.close();

	// write simulation memory file
	outfilesim << "// memory data file (do not edit the following line - required for mem load use)" << endl;
	outfilesim << "// instance=/multicycle/DataMem/b2v_inst/altsyncram_component/mem_data" << endl;
	outfilesim << "// format=mti addressradix=h dataradix=h version=1.0 wordsperline=1" << endl;
	
	for (int i = 0; i < MEM_SIZE; i++)
	{
		char str[10];
		sprintf(str, "%02x", static_cast<unsigned int>(i));
		outfilesim << str << ": ";

		sprintf(str, "%04x", static_cast<unsigned int>(mem[i]));

		outfilesim << str << endl;
	}

	outfilesim.close();
	
	return 0;
}
