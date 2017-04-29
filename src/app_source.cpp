#include <Windows.h>
#include <iostream>
#include <fstream>
#include <conio.h>
#include <algorithm>
#include <math.h>
#include <WinIoCtl.h>
#include <vector>
#include <regex>
#include <stdio.h>
#include <cstdlib>
#include <string>
#include <iomanip>

using namespace std;

//Int to string conversion
string intoStr(int n)
{
     string tmp;
     if(n < 0) {
      tmp = "-";
      n = -n;
     }
     if(n > 9)
      tmp += intoStr(n / 10);
     tmp += n % 10 + 48;
     return tmp;
}


//change number of bytes into string of characters(in GiB/MiB/KiB/B)
string bytesToString(unsigned long long bytes){
    if(bytes<1024)
        return intoStr(bytes)+"B";
    else if(bytes<1048576)
        return intoStr(bytes/1024)+"KiB";
    else if(bytes<1073741824)
        return intoStr(bytes/1024/1024)+"MiB";
    else
        return intoStr(bytes/1024/1024/1024)+"GiB";
}

//Check size of file
std::ifstream::pos_type filesize(string filename)
{
    std::ifstream in(filename.c_str(), std::ifstream::ate | std::ifstream::binary);
    return in.tellg();
}

//check current Y coordinate of console cursor
int wherey()
  {
  CONSOLE_SCREEN_BUFFER_INFO csbi;
  if (!GetConsoleScreenBufferInfo(
         GetStdHandle( STD_OUTPUT_HANDLE ),
         &csbi
         ))
    return -1;
  return csbi.dwCursorPosition.Y;
  }
//change console cursor X coordinate to desired position
void gotox(int x)
{

     COORD c;
     c.X = x;
     c.Y = wherey();
     SetConsoleCursorPosition (GetStdHandle (STD_OUTPUT_HANDLE),c);

}
//Read raw bytes from selected device/path
char* readBytes(const char *target, unsigned int offset = 0, unsigned int length = 512)
{

    DWORD dwRead;
    HANDLE hTarget=CreateFile(target,GENERIC_READ,FILE_SHARE_VALID_FLAGS,0,OPEN_EXISTING,0,0);
    if(hTarget==INVALID_HANDLE_VALUE)
    {
         CloseHandle(hTarget);
         return NULL;
    }
    if(SetFilePointer(hTarget,offset,0,FILE_BEGIN) == INVALID_SET_FILE_POINTER)
    {
        CloseHandle(hTarget);
        return NULL;
    }
    char* buffer = new char[length];
    ReadFile(hTarget,buffer,length,&dwRead,0);
    CloseHandle(hTarget);
    return buffer;
}
//write raw bytes from selected device/path
bool writeBytes(const char *target, char*& buffer, unsigned int offset = 0, unsigned int length = 512)
{

    DWORD dwWritten;
    HANDLE hTarget=CreateFile(target,GENERIC_WRITE,FILE_SHARE_VALID_FLAGS,0,OPEN_EXISTING,0,0);
    if(hTarget==INVALID_HANDLE_VALUE)
    {
         CloseHandle(hTarget);
         return true;
    }
    if(SetFilePointer(hTarget,offset,0,FILE_BEGIN) == INVALID_SET_FILE_POINTER)
    {
        CloseHandle(hTarget);
        return true;
    }
    WriteFile(hTarget,buffer,length,&dwWritten,0);
    CloseHandle(hTarget);
    return false;
}


int main()
{
    //Checking administrator rights(It may not be the right way but it works)
    cout << "Checking privileges...";
    char * testtable = readBytes("\\\\.\\PhysicalDrive0");
    if(testtable == NULL)
    {
        system("cls");
        cout << "Error! Need administrator rights...(right click->run as administrator)";
        getch();
        return 1;
    }
    delete[] testtable;
//Declaring filename variables
    string filename, FILENAME, tmp;
//result variable for regex
    smatch result;
//WinAPI variables
    char drive_letter = 'A';
    char drive_path[] = "\\\\.\\X:";
    VOLUME_DISK_EXTENTS diskInfo;
    PARTITION_INFORMATION partitionInfo;
    DWORD bytesread = 0;
    bool another_letter = false;

//outputting a small warning
    system("cls");
    cout << "\
Disclaimer: Be aware what you're doing, in worst case your OS won't boot(of course only if you make it that way)\n\
\n\
(press anything to continue)";
    getch();

//Obtaining 8.3 Filename
    do
    {
        //Obtaining raw filename with dot, and making sure it is valid(regex)
        system("cls");
        while(true)
        {

            cout << "\
Enter the FAT32 filename(max 8 chars for name, and 3 for extension, with dot):\n\
------------------------------------------------------------------------------\n";
            cin.clear();
            cin.sync();
            cin >> filename;
            if(cin.good() && regex_match(filename, result, (regex)"([A-Za-z0-9\\s!#%&'@_`~\\$\\(\\)\\^\\{\\}\\-]{1,8})\\.([A-Za-z0-9\\s!#%&'@_`~\\$\\(\\)\\^\\{\\}\\-]{1,3})"))
                break;
            else{
                system("cls");
                cout << "Error, wrong filename. Try again:\n\n";
            }

        }
//Just making sure filename is correct
        system("cls");
        cout << "\
Is that correct?(Enter-yes)\n\
---------------------------\n" << filename;

    }
    while(getch() != 13);
//Transforming to 8.3 format for directory entry
    tmp = result[1];
    while(tmp.length() < 8)
        tmp += " ";
    FILENAME = tmp;
    tmp = result[2];
    while(tmp.length() < 3)
        tmp += " ";
    FILENAME += tmp;
    transform(FILENAME.begin(), FILENAME.end(), FILENAME.begin(), ::toupper);
//Reading physical drives list into a vector

    FILE* Drives = popen("wmic diskdrive get index,model,size,partitions", "r");
    tmp.clear();
    vector <string> driveslist;
    while(!feof(Drives)){
        tmp += (char)fgetc(Drives);
        if(tmp.substr(tmp.length()-1) == "\n"){
            driveslist.push_back(tmp);
            tmp.clear();
        }
    }
    pclose(Drives);
//popping empty line from the end of vector
    driveslist.pop_back();
//sorting devices by index
    sort(driveslist.begin()+(unsigned int)1, driveslist.end());
//Outputting information
    system("cls");
    cout << "\
Select device you want to install bootsector on:(Enter index value of device)\n\
-----------------------------------------------------------------------------\n";
    cout << driveslist.at(0).substr(0,driveslist.at(0).find_first_of("\n")-1);
//And outputting custom info
    gotox(60);
    cout << "Mounted volumes\n";
//Outputting data(information about Physical drives and letters belonging to them)
    for(unsigned int i=1;i<driveslist.size(); i++){
        //extracting device number, device name, and size from list
        regex_search(driveslist.at(i), result, (regex)"((\\d+)\\s+[\\sa-zA-Z\\d-]+\\s{2,}\\d\\s{2,})(\\d+)");
        //outputting informations, sizes of drives in matching units instead of bytes
        tmp = result[3];
        cout << result[1] << bytesToString((unsigned long long)atoll((char*)tmp.c_str()));
        //outputting custom info about letters belonging to physical drives
        gotox(60);
        //setting variables for WinAPI functions
        drive_letter = 'A';
        bytesread = 0;
        another_letter = false;
        //search for every letter that belongs to current physical drive
        for(unsigned int k=0, j=0; j<GetLogicalDrives(); k++,j=pow(2,k),drive_letter++)
        {
            if((GetLogicalDrives() & j) != 0){
                drive_path[4] = drive_letter;
                HANDLE filehandle = CreateFile(drive_path,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0);
                DeviceIoControl(filehandle,IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,NULL, 0,&diskInfo,sizeof(diskInfo),&bytesread,NULL);
                DeviceIoControl(filehandle,IOCTL_DISK_GET_PARTITION_INFO,NULL, 0,&partitionInfo,sizeof(partitionInfo),&bytesread,NULL);
                CloseHandle(filehandle);
                //and if letter matches, display it
                if(diskInfo.Extents[0].DiskNumber == (unsigned int)atoi(string(result[2]).c_str())){
                    if(another_letter)
                        cout << ", ";
                    cout << drive_letter << ":";
                    another_letter=true;
                }

            }
        }
        cout << endl;
    }
    //Get input from user(device number)
    unsigned int chosenDevice;
    do{
        cin.clear();
        cin.sync();
        cin >> chosenDevice;
    }
    while(!cin.good() || chosenDevice >= driveslist.size()-1);
    //Print selection of partitions
    system("cls");
    drive_letter = 'A';
    bytesread = 0;
    cout << "\
Select partition you want to boot from(where file will be copied):\n\
(Enter index value of partition)\n\
------------------------------------------------------------------\n";
    cout << "Index     Letter    Start     End       Size      File System";

    unsigned int maxPart=0, minPart = 128;
    for(unsigned int i=0, j=0; j<GetLogicalDrives(); i++,j=pow(2,i),drive_letter++){
            if((GetLogicalDrives() & j) != 0){
                drive_path[4] = drive_letter;
                HANDLE filehandle = CreateFile(drive_path,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0);
                DeviceIoControl(filehandle,IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,NULL, 0,&diskInfo,sizeof(diskInfo),&bytesread,NULL);
                DeviceIoControl(filehandle,IOCTL_DISK_GET_PARTITION_INFO,NULL, 0,&partitionInfo,sizeof(partitionInfo),&bytesread,NULL);
                CloseHandle(filehandle);
                //Print all info about partition
                if(diskInfo.Extents[0].DiskNumber == chosenDevice && partitionInfo.PartitionNumber !=0){
                    if(partitionInfo.PartitionNumber > maxPart)
                        maxPart = partitionInfo.PartitionNumber;
                    if(partitionInfo.PartitionNumber-1 < minPart)
                        minPart = partitionInfo.PartitionNumber-1;
                    cout << endl;
                    cout << partitionInfo.PartitionNumber-1;
                    gotox(10);
                    cout << drive_letter << ":";
                    gotox(20);
                    cout << bytesToString((unsigned long long)partitionInfo.StartingOffset.QuadPart);
                    gotox(30);
                    cout << bytesToString((unsigned long long)partitionInfo.StartingOffset.QuadPart+(unsigned long long)partitionInfo.PartitionLength.QuadPart);
                    gotox(40);
                    cout << bytesToString((unsigned long long)partitionInfo.PartitionLength.QuadPart-(unsigned long long)partitionInfo.StartingOffset.QuadPart);
                    gotox(50);
                    if(partitionInfo.PartitionType == 0x0B || partitionInfo.PartitionType == 0x0C)
                        cout << "Supported(FAT32)";
                    else
                        cout << "Not Supported";
                }
            }
        }
//get info from user(index of chosen partition)
    unsigned int chosenPart;
    cout << endl;
    do{
        cin.clear();
        cin.sync();
        cin >> chosenPart;
    }
    while(!cin.good() || chosenPart < minPart || chosenPart >= maxPart);
//get letter of selected partition(just to print it later)
    drive_letter = 'A';
    bytesread = 0;
    for(unsigned int i=0, j=0; j<GetLogicalDrives(); i++,j=pow(2,i),drive_letter++){
        if((GetLogicalDrives() & j) != 0){
            drive_path[4] = drive_letter;
            HANDLE filehandle = CreateFile(drive_path,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,0,OPEN_EXISTING,0,0);
            DeviceIoControl(filehandle,IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS,NULL, 0,&diskInfo,sizeof(diskInfo),&bytesread,NULL);
            DeviceIoControl(filehandle,IOCTL_DISK_GET_PARTITION_INFO,NULL, 0,&partitionInfo,sizeof(partitionInfo),&bytesread,NULL);
            CloseHandle(filehandle);
            if(diskInfo.Extents[0].DiskNumber == chosenDevice && partitionInfo.PartitionNumber-1 == chosenPart)
                break;

        }
    }
//load bootsector of selected drive
    tmp = "\\\\.\\PhysicalDrive"+intoStr(chosenDevice);
    char * bootsector = readBytes(tmp.c_str(),0);
    if(bootsector == NULL){
        system("cls");
        cout << "Error! Can't access selected device...";
        getch();
        return 1;
    }
//saving current bootsector for backup
    fstream bckup;
    bckup.open("backup/backup_bootsector.bin", ios::out|ios::trunc);
    bckup.write(bootsector, 512);
    bckup.close();
//Clear boot field in every partition entry
    for(int i = 0; i < 4; i++)
        bootsector[0x01BE + i*0x10] = (unsigned char)0x00;
//And set boot field in selected partition
    bootsector[0x01BE + chosenPart*0x10] = (unsigned char)0x80;
//Assembly of bootsector code with user filename
    string nasm_command = "nasm -o bin/bootloader.bin -f bin -d_FILENAME=\"'"+FILENAME+"'\" src/bootloader.asm";
    system(nasm_command.c_str());
//checking if bootsector code won't overlap MBR entries
    if(filesize("bin/bootloader.bin") > 446)
    {
        system("cls");
        cout << "Critical Error(binary too big)";
        getch();
        return 1;
    }
//Loading binary bootsector code over previously loaded bootsector code
    system("cls");
    ifstream f32exe;
    f32exe.open("bin/bootloader.bin", ios::binary|ios::in);
    f32exe.seekg(f32exe.beg);
    f32exe.read(bootsector, 446);
    f32exe.close();
//Before writing to device, a quick check if filesystem is FAT32
    if((unsigned char)bootsector[0x1BE +chosenPart*0x10+0x04] != 0x0B && (unsigned char)bootsector[0x1BE +chosenPart*0x10+0x04] != 0x0C)
    {
        cout << "Error! Partition type not supported... \nMake sure you format this partition as FAT32";
        getch();
        return 1;
    }
//If all is good, write new bootsector to the device
    if(writeBytes(tmp.c_str(), bootsector) == 0)
        cout << "Done! Now copy \"" << filename << "\" to \""<< drive_letter <<":\" partition";
    else{
        cout << "Writing to device finished with errors...";
        getch();
        return 1;
    }
    getch();
    return 0;
}
