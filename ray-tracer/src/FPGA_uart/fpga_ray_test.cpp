// Standalone Windows UART test for test6_12ray_controller.s. No SDL/CUDA needed.
#define NOMINMAX
#include <windows.h>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using Word = uint16_t;
using Input = std::array<Word,40>;
using Output = std::array<Word,20>;
struct RayCase { std::array<int,3> o,c,d; int radius; }; // Q8.8 integers
const std::array<RayCase,12> cases = {{
 {{{0,0,-1280}},{{0,0,0}},{{0,0,256}},256},
 {{{0,0,-1280}},{{768,0,0}},{{0,0,256}},256},
 {{{256,256,-1024}},{{384,256,0}},{{0,0,256}},192},
 {{{-256,0,-768}},{{256,256,0}},{{0,0,256}},320},
 {{{-768,0,0}},{{0,0,0}},{{256,0,0}},256},
 {{{-1024,256,0}},{{0,0,0}},{{256,0,0}},256},
 {{{-512,512,0}},{{0,0,0}},{{256,0,0}},256},
 {{{-1280,128,0}},{{0,0,0}},{{256,0,0}},256},
 {{{0,-512,0}},{{0,0,0}},{{0,256,0}},128},
 {{{384,-768,0}},{{0,0,0}},{{0,256,0}},256},
 {{{256,-1024,0}},{{0,0,0}},{{0,256,0}},256},
 {{{128,512,128}},{{0,0,0}},{{0,-256,0}},256}
}};
int signed_word(Word x) { return x<32768 ? int(x) : int(x)-65536; }
Word add(Word a,Word b) {return Word(unsigned(a)+b);}
Word sub(Word a,Word b) {return Word(unsigned(a)-b);}
Word mul(Word a,Word b) {
    const int64_t p=int64_t(signed_word(a))*signed_word(b);
    // Arithmetic right shift by eight, including negative nonmultiples of 256.
    return Word(p>=0 ? p/256 : -((-p+255)/256));
}
Input pack(const std::array<RayCase,4>& rays) {
    Input out{};
    for(int lane=0;lane<4;++lane) {
        for(int axis=0;axis<3;++axis) {
            out[12*axis+lane]=Word(rays[lane].o[axis]);
            out[12*axis+4+lane]=Word(rays[lane].c[axis]);
            out[12*axis+8+lane]=Word(rays[lane].d[axis]);
        }
        out[36+lane]=Word(rays[lane].radius);
    }
    return out;
}
Output reference(const Input& in) {
    Output out{};
    for(int lane=0;lane<4;++lane) {
        Word a=0,b=0,c=0;
        for(int axis=0;axis<3;++axis) {
            Word oc=sub(in[12*axis+lane],in[12*axis+4+lane]);
            Word d=in[12*axis+8+lane];
            a=add(a,mul(d,d));b=add(b,mul(oc,d));c=add(c,mul(oc,oc));
        }
        b=add(b,b);c=sub(c,mul(in[36+lane],in[36+lane]));
        Word ac=mul(a,c);ac=add(ac,ac);ac=add(ac,ac);
        Word delta=sub(mul(b,b),ac);
        out[lane]=a;out[4+lane]=b;out[8+lane]=c;out[12+lane]=delta;
        out[16+lane]=signed_word(delta)>=0 ? 0x100 : 0;
    }
    return out;
}
// Same half-B/root test as CPU/objects.hpp and GPU_cuda/objects_cuda.cuh.
// Kept independent of their SDL/CUDA headers. This does not execute CUDA.
bool floating_hit(const RayCase& ray) {
    double a=0,h=0,c=0;
    for(int i=0;i<3;++i) {
        double oc=(ray.o[i]-ray.c[i])/256.0,d=ray.d[i]/256.0;
        a+=d*d;h+=oc*d;c+=oc*oc;
    }
    c-=std::pow(ray.radius/256.0,2);
    double delta=h*h-a*c;
    if(a==0 || delta<0) return false;
    double t=(-h-std::sqrt(delta))/a;
    if(t<=0.001)t=(-h+std::sqrt(delta))/a;
    return t>0.001;
}
template<size_t N> std::vector<uint8_t> encode(const std::array<Word,N>& words) {
    std::vector<uint8_t> bytes;
    for(auto w:words){bytes.push_back(uint8_t(w));bytes.push_back(uint8_t(w>>8));}
    return bytes;
}
Output decode(const std::vector<uint8_t>& bytes) {
    if(bytes.size()!=40)throw std::runtime_error("Expected 40 response bytes");
    Output out{};for(size_t i=0;i<20;++i)out[i]=Word(bytes[2*i]|(unsigned(bytes[2*i+1])<<8));
    return out;
}
void require(bool ok,const char* text) {if(!ok)throw std::runtime_error(text);}
void self_test() {
    const Word golden[3][20]={
      {256,256,256,256,0xF600,0xF600,0xF800,0xFA00,0x1800,0x2100,0x0FB0,0x0C70,0x0400,0xE000,0x0140,0xF240,256,0,256,0},
      {256,256,256,256,0xFA00,0xF800,0xFC00,0xF600,0x0800,0x1000,0x0700,0x1840,0x0400,0,0xF400,0x0300,256,256,0,256},
      {256,256,256,256,0xFC00,0xFA00,0xF800,0xFC00,0x03C0,0x0A40,0x1000,0x0380,0x0100,0xFB00,0,0x0200,256,0,256,256}};
    for(int g=0;g<3;++g) {
        std::array<RayCase,4> rays{};for(int l=0;l<4;++l)rays[l]=cases[4*g+l];
        auto result=reference(pack(rays));
        for(int i=0;i<20;++i)require(result[i]==golden[g][i],"test6 golden mismatch");
        require(decode(encode(result))==result,"byte roundtrip mismatch");
    }
    require(mul(Word(-1),1)==65535,"negative Q8.8 truncation");
    require(add(65535,1)==0,"16-bit wrapping");
    require(encode(std::array<Word,2>{0x0100,0xFB00})==std::vector<uint8_t>({0,1,0,251}),"byte order");
    std::cout<<"Self-test PASS: 60 golden words, Q8.8 arithmetic, little-endian serialization.\n";
}
std::runtime_error win_error(const char* op) {
    return std::runtime_error(std::string(op)+" failed (Windows error "+std::to_string(GetLastError())+")");
}
class Serial {
    HANDLE handle=INVALID_HANDLE_VALUE;
public:
    Serial(const std::string& port,DWORD baud) {
        const std::string path=port.rfind("\\\\.\\",0)==0 ? port : "\\\\.\\"+port;
        handle=CreateFileA(path.c_str(),GENERIC_READ|GENERIC_WRITE,0,nullptr,OPEN_EXISTING,0,nullptr);
        if(handle==INVALID_HANDLE_VALUE)throw win_error("Open COM port");
        try {
            DCB d{};d.DCBlength=sizeof(d);
            if(!GetCommState(handle,&d))throw win_error("GetCommState");
            d.BaudRate=baud;d.ByteSize=8;d.Parity=NOPARITY;d.StopBits=ONESTOPBIT;
            d.fBinary=TRUE;d.fParity=FALSE;d.fOutxCtsFlow=FALSE;d.fOutxDsrFlow=FALSE;
            d.fDtrControl=DTR_CONTROL_DISABLE;d.fDsrSensitivity=FALSE;
            d.fOutX=FALSE;d.fInX=FALSE;d.fErrorChar=FALSE;d.fNull=FALSE;
            d.fRtsControl=RTS_CONTROL_DISABLE;d.fAbortOnError=FALSE;
            if(!SetCommState(handle,&d))throw win_error("SetCommState");
            COMMTIMEOUTS t{};t.ReadIntervalTimeout=MAXDWORD;t.ReadTotalTimeoutConstant=100;
            t.ReadTotalTimeoutMultiplier=MAXDWORD;t.WriteTotalTimeoutConstant=100;
            if(!SetCommTimeouts(handle,&t))throw win_error("SetCommTimeouts");
            if(!PurgeComm(handle,PURGE_RXCLEAR|PURGE_TXCLEAR))throw win_error("PurgeComm");
        } catch(...) {CloseHandle(handle);handle=INVALID_HANDLE_VALUE;throw;}
    }
    ~Serial(){if(handle!=INVALID_HANDLE_VALUE)CloseHandle(handle);}
    Serial(const Serial&)=delete;Serial& operator=(const Serial&)=delete;
    void transfer(std::vector<uint8_t>& bytes,bool write,int timeout_ms) {
        auto deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(timeout_ms);
        size_t offset=0;
        while(offset<bytes.size()) {
            if(std::chrono::steady_clock::now()>=deadline)
                throw std::runtime_error(std::string(write?"Write":"Read")+" timeout after "+std::to_string(offset)+"/"+std::to_string(bytes.size())+" bytes. Reset FPGA before retrying the raw stream.");
            DWORD errors=0;COMSTAT stat{};
            if(!ClearCommError(handle,&errors,&stat))throw win_error("ClearCommError");
            if(errors)throw std::runtime_error("UART error flags "+std::to_string(errors)+"; reset FPGA before retrying");
            DWORD count=0;
            BOOL ok=write ? WriteFile(handle,bytes.data()+offset,DWORD(bytes.size()-offset),&count,nullptr)
                          : ReadFile(handle,bytes.data()+offset,DWORD(bytes.size()-offset),&count,nullptr);
            if(!ok)throw win_error(write?"WriteFile":"ReadFile");
            offset+=count;
        }
    }
};
int number(const std::string& text,int minimum,int maximum) {
    size_t pos=0;int n=std::stoi(text,&pos);
    if(pos!=text.size() || n<minimum || n>maximum)throw std::runtime_error("Invalid numeric argument: "+text);
    return n;
}
int main(int argc,char** argv) try {
    std::string port,vector_dir;int rays=10,baud=1000000,timeout=15000;bool test_only=false;
    for(int i=1;i<argc;++i) {
        std::string a=argv[i];
        if(a=="--help") {
            std::cout<<"fpga_ray_test [--port COM5] [--rays 10] [--baud 1000000] [--timeout-ms 15000]\n"
                       "              [--self-test] [--vectors DIR]\n"
                       "Without --port: CPU reference only. Ray cases repeat every 12.\n";return 0;
        }
        if(a=="--self-test"){test_only=true;continue;}
        if(i+1>=argc)throw std::runtime_error("Missing option value");
        std::string v=argv[++i];
        if(a=="--port")port=v;
        else if(a=="--rays")rays=number(v,1,100000);
        else if(a=="--baud")baud=number(v,1,4000000);
        else if(a=="--timeout-ms")timeout=number(v,100,3600000);
        else if(a=="--vectors")vector_dir=v;
        else throw std::runtime_error("Unknown option: "+a);
    }
    self_test();if(test_only)return 0;
    std::ofstream input_file,expected_file;
    if(!vector_dir.empty()) {
        std::filesystem::create_directories(vector_dir);
        input_file.open(std::filesystem::path(vector_dir)/"inputs.hex");
        expected_file.open(std::filesystem::path(vector_dir)/"expected.hex");
        require(bool(input_file)&&bool(expected_file),"Cannot write vector files");
    }
    std::unique_ptr<Serial> serial;
    if(!port.empty())serial=std::make_unique<Serial>(port,DWORD(baud));
    std::cout<<rays<<" rays; "<<(rays+3)/4<<" groups; "<<((4-rays%4)%4)<<" padded lanes. "
             <<(serial?"FPGA verification":"CPU reference only (no board accessed)")<<"\n";
    int failures=0;
    for(int base=0;base<rays;base+=4) {
        std::array<RayCase,4> batch{};
        for(int l=0;l<4;++l)batch[l]=cases[(base+l<rays?base+l:base)%12];
        Input input=pack(batch);Output expected=reference(input),actual=expected;
        if(input_file.is_open()) {
            for(auto w:input)input_file<<std::hex<<std::setw(4)<<std::setfill('0')<<w<<'\n';
            for(auto w:expected)expected_file<<std::hex<<std::setw(4)<<std::setfill('0')<<w<<'\n';
        }
        if(serial) {
            auto bytes=encode(input);serial->transfer(bytes,true,timeout);
            std::vector<uint8_t> reply(40);serial->transfer(reply,false,timeout);actual=decode(reply);
            const char* names[]={"a","b","c","delta","flag"};
            for(int i=0;i<20;++i)if(actual[i]!=expected[i]) {
                ++failures;std::cerr<<"Mismatch group "<<base/4<<" lane "<<i%4<<" "<<names[i/4]
                    <<" expected=0x"<<std::hex<<expected[i]<<" actual=0x"<<actual[i]<<std::dec<<'\n';
            }
        }
        for(int l=0;l<4 && base+l<rays;++l)
            std::cout<<"ray "<<std::setw(2)<<base+l<<" delta="<<std::setw(7)<<signed_word(actual[12+l])/256.0
                     <<" discriminant_hit="<<(actual[16+l]!=0)<<" float_forward_hit="<<floating_hit(batch[l])<<'\n';
        if(failures)break; // Avoid continuing a possibly misaligned raw stream.
    }
    if(failures){std::cerr<<"FAIL: "<<failures<<" mismatched words.\n";return 2;}
    std::cout<<(serial?"PASS: every returned word matched, including padding.\n":"Reference complete; use --port COMn to verify FPGA.\n");
    return 0;
} catch(const std::exception& e){std::cerr<<"Error: "<<e.what()<<'\n';return 1;}
