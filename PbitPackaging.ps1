# load ZIP methods
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO
#Add-Type -AssemblyName System.IO.Packaging
Add-Type -AssemblyName System.Runtime
#Add-Type -AssemblyName System.Text
Add-Type -AssemblyName System.Text.Encoding.Extensions

$PSScriptRoot

. "$PSScriptRoot\PbitConfig.ps1"


$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False


function GetLocalUriPath {
  [OutputType([string])]
  param ([ValidateNotNullOrEmpty()]
       [string] $rootDir,
              [ValidateNotNullOrEmpty()]
       [System.Uri] $uri)

   return  [System.IO.Path]::Combine( $rootDir, $uri.ToString().Substring(1 ))

}


function SavePackagePart {

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.Packaging.PackagePart] $packagePart,
       [ValidateNotNullOrEmpty()]
       [string] $rootDir

    )

    "Running SavePackagePartAsFile"


    $rootDir


    $pkgPartTargetPath = GetLocalUriPath -rootDir $rootDir -uri $packagePart.Uri

    $pkgPartTargetDir = [System.IO.Path]::GetDirectoryName($pkgPartTargetPath)

    $pkgPartTargetDir 




    if (!(Test-Path $pkgPartTargetDir)) 
    {
            [System.IO.Directory]::CreateDirectory($pkgPartTargetDir)
    }


    $partFS = [System.IO.File]::OpenWrite($pkgPartTargetPath)


    $pkgPartStrm = $packagePart.GetStream()

    $pkgPartStrm.CopyTo($partFS)

    $partFS.Close()
    $pkgPartStrm.Close()

    return

}


function ExaminePackagePart {
    [OutputType([PSCustomObject])]
    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.Packaging.PackagePart] $pkgPart
    )

    
    $pkgPartApi =  ConvertTo-Json $pkgPart | ConvertFrom-Json

    $pkgPartApiProperties = $pkgPartApi.PSObject.Properties

    $pkgPartApiProperties.Remove('Package')


    return $pkgPartApi

}


function SavePackagePartAsFile {

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.Packaging.PackagePart] $packagePart,
       [ValidateNotNullOrEmpty()]
       [string] $rootDir

    )

    "Running SavePackagePartAsFile"


    $rootDir


    $pkgPartTargetPath = [System.IO.Path]::Combine( $rootDir, $packagePart.Uri.ToString().Substring(1 ))

    $pkgPartTargetDir = [System.IO.Path]::GetDirectoryName($pkgPartTargetPath)

    $pkgPartTargetDir 




    if (!(Test-Path $pkgPartTargetDir)) 
    {
            [System.IO.Directory]::CreateDirectory($pkgPartTargetDir)
    }

     $pkgPartTargetPath


        $packagePart

        $pkgPartStrm = $packagePart.GetStream()

        $pkgPartStrm


        $tmpMS = New-Object System.IO.MemoryStream

        $tmpMSBuffer = [System.Byte[]]::CreateInstance([System.Byte],65536)

        $cnt = 1

        while($cnt -gt 0)
        {

            $cnt 

            $cnt = $pkgPartStrm.Read($tmpMSBuffer,0,$tmpMSBuffer.Length)

            $tmpMS.Write($tmpMSBuffer,0,$cnt)

            #$tmpMSBuffer

        }

        $pkgPartContents = [System.Text.Encoding]::UTF8.GetString($tmpMS.ToArray())

        $pkgPartContents = $pkgPartContents.Replace("`r`n", "`n" ).Replace("`n", "`r`n")   
        
        
        [System.IO.File]::WriteAllText( $pkgPartTargetPath, $pkgPartContents)                      

        #$pkgPartContents  | Set-Content -Encoding UTF8 $pkgPartTargetPath
        
        $pkgPartStrm.Close()

}


function ExportPackageToDirectory
{

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $packageFile,
        [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $exportDir
    )

    $partsJson = [System.IO.Path]::Combine( $exportDir.FullName , "packageParts.json")




    if (Test-Path $exportDir) 
    {
        Remove-Item -path $exportDir -recurse -force 
    }

    New-Item -Path $exportDir -ItemType Directory 



    "Exporting Package " + $packageFile.FullName + " to " + $exportDir.FullName
          

   $exPkg = [System.IO.Packaging.Package]::Open( $packageFile.FullName, [System.IO.FileMode]::Open)

   $exPkgApi = ConvertTo-Json $exPkg | ConvertFrom-Json


   $exPkgApiProperties = $exPkgApi.PSObject.Properties


       $exPkgApi | Add-Member -MemberType NoteProperty -Name 'PackageParts' -Value  @()
   
       foreach ($pkgpart in $exPkg.GetParts())
       {

           $partApi =   ExaminePackagePart -pkgPart $pkgpart

           $exPkgApi.PackageParts += $partApi

           SavePackagePart -packagePart $pkgpart -rootDir $exportDir
       
       }

    $exPkgApi.PackageParts

    $partsJson

    $exPkgApi | ConvertTo-Json -Depth 100 | Set-Content -Path $partsJson -Force


     $exPkg.Close()



}


function CreatePackageFromDirectory
{

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $packageRootDir,
        [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $packageFile
    )
        
    
        $partsJson = [System.IO.Path]::Combine( $packageRootDir.FullName , "packageParts.json")

        $partsJson


        $packPkg = [System.IO.Packaging.Package]::Open( $packageFile, [System.IO.FileMode]::Create)


        $exPkgApi = Get-Content -Path $partsJson -Raw | ConvertFrom-Json




       foreach ($packpart in $exPkgApi.PackageParts)
       {


           $newPart =   $packPkg.CreatePart($packpart.Uri,$packpart.ContentType,$packpart.CompressionOption)

           $packPartPath = GetLocalUriPath -rootDir $packageRootDir -uri $packpart.Uri


          $partFS = [System.IO.File]::OpenRead($packPartPath)

            $partFS.CopyTo($newPart.GetStream())

          $partFS.Close()

     
       }


   $packPkg.Close()

}


function NextPackageFromBinaryReader
{
    [OutputType([System.IO.Packaging.Package])]
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.BinaryReader] $reader

    )

        $mshcnt = $reader.ReadInt32()

        if ($mshcnt -eq 0){
               $mshcnt = $reader.ReadInt32()
        }

        $mshBytes = $reader.ReadBytes($mshcnt)

        $mshMS = New-Object System.IO.MemoryStream(,$mshBytes)
                    
        [System.IO.Packaging.Package]::Open($mshMS, 3)

}


function UnpackPbitDataMashupExtraBytes
{
    [OutputType([System.IO.Packaging.Package])]
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $extraBytesFile
    )

        $mshcnt = $reader.ReadInt32()

        if ($mshcnt -eq 0){
               $mshcnt = $reader.ReadInt32();
        }



        $mshBytes = $reader.ReadBytes($mshcnt)

        
        [System.IO.File]::WriteAllBytes([System.IO.Path]::Combine($testdir,"PermissionList.xml"),$mshBytes)


        $mshcnt = $reader.ReadInt32()
        $mshBytes = $reader.ReadBytes($mshcnt)
        $pkg2path = [System.IO.Path]::Combine($testdir,"pkg2")
        [System.IO.File]::WriteAllBytes($pkg2path,$mshBytes)

        $pkg2Stream = [System.IO.File]::Open($pkg2path, 3)

        $pkg2BinaryReader = New-Object System.IO.BinaryReader ($pkg2Stream)

        #$pkg2 =  NextPackageFromBinaryReader -reader $pkg2BinaryReader

        $mshcnt = $pkg2BinaryReader.ReadInt32()

        if ($mshcnt -eq 0){
               $mshcnt = $pkg2BinaryReader.ReadInt32();
        }

        $mshBytes = $pkg2BinaryReader.ReadBytes($mshcnt)
      
        [System.IO.File]::WriteAllBytes([System.IO.Path]::Combine($testdir,"LocalPackageMetadataFile.xml"),$mshBytes)


        $pkg2ExtraMs = New-Object System.IO.MemoryStream

        $pkg2extraCount = 0

        $pkg2ExtraEof = $false


        $mshcnt = $pkg2BinaryReader.ReadInt32()


        "pkg2ExtraFirstInt " + $mshcnt


        $mshBytes = $pkg2BinaryReader.ReadBytes($mshcnt)
        
        [System.IO.File]::WriteAllBytes([System.IO.Path]::Combine($testdir,"LocalPackageMetadataFile.PK"),$mshBytes)



        while (!($pkg2ExtraEof)){
            try
            {
               $pkg2ExtraMs.WriteByte($pkg2BinaryReader.ReadByte())
               $pkg2extraCount ++
            }
            catch
            {
             $pkg2ExtraEof = $true
            }
        }

        "pkg2extraCount" 
        $pkg2extraCount


        $pkg2BinaryReader.Close()
        $pkg2Stream.Close()

  

    ##  Finish Extra Bytes...

        $mshcnt = $reader.ReadInt32()


        "Finish Extra Bytes.... " + $mshcnt

        #if ($mshcnt -eq 0){
        #       $mshcnt = $reader.ReadInt32();
        #}



        $mshBytes = $reader.ReadBytes($mshcnt)

        
        [System.IO.File]::WriteAllBytes([System.IO.Path]::Combine($testdir,"final.data"),$mshBytes)



         #$pkg2.Close()

        #$mshcnt = $reader.ReadInt32()

        #"File2 sizeCount " +  $mshcnt

        #$mshBytes = $reader.ReadBytes($mshcnt)

        #[System.IO.File]::WriteAllBytes([System.IO.Path]::Combine($testdir,"File2"),$mshBytes)

}

function UnpackPbitDataMashup
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile

    )

        if (!($pbitPartFile.Exists)){
            return
        }

                    
        $pbitMUExtractDir = [System.IO.Path]::Combine($pbitPartFile.DirectoryName,"DataMashup\")


        $pbitMUTmpExtractDir = [System.IO.Path]::Combine($pbitPartFile.DirectoryName,"DataMashupTmp\")

        $partsJson = [System.IO.Path]::Combine( $pbitMUTmpExtractDir , "packageParts.json")

        if (!(Test-Path $pbitMUTmpExtractDir)) 
        {
                New-Item -Path $pbitMUTmpExtractDir -ItemType Directory
        }

        $mashupStream = [System.IO.File]::Open($pbitPartFile.FullName, 3)

        $mashupBinaryReader = New-Object System.IO.BinaryReader ($mashupStream)

        $mashupPackage =  NextPackageFromBinaryReader -reader $mashupBinaryReader

        $muExtraMs = New-Object System.IO.MemoryStream

        $extraCount = 0

        while (!($muExtraEof)){
            try
            {
               $muExtraMs.WriteByte($mashupBinaryReader.ReadByte())
               $extraCount ++
            }
            catch
            {
             $muExtraEof = $true
            }
        }

        "ExtraCount" 
        $extraCount


        [System.IO.File]::WriteAllBytes($pbitMUTmpExtractDir + "extraBytes", $muExtraMs.ToArray())


        $exPkgApi = ConvertTo-Json $mashupPackage | ConvertFrom-Json

        $mashupPackage

        $exPkgApiProperties = $exPkgApi.PSObject.Properties


        $exPkgApi | Add-Member -MemberType NoteProperty -Name 'PackageParts' -Value  @()

        $mashupPackage.GetParts()

        foreach ($mashupPart in $mashupPackage.GetParts())
        {

            $partApi =   ExaminePackagePart -pkgPart $mashupPart


            #if ($mashupPart.Uri.ToString().EndsWith(".m")){

             #   "This is the Query"

            #    $partApi.CompressionOption = -1
           # }


            $exPkgApi.PackageParts += $partApi


            $mashupPartTargetPath =  $pbitMUExtractDir +   $mashupPart.Uri.ToString()


            SavePackagePartAsFile -packagePart $mashupPart -rootDir $pbitMUTmpExtractDir

            #$mashupPartC = 


        }


        $exPkgApi | ConvertTo-Json -Depth 100 | Set-Content -Path $partsJson -Force


        $mashupPackage.Close();
                    
        $mashupBinaryReader.Close();
        $mashupStream.Close();
                    
        #  Get-Content $pbitEntry.FullName  -Encoding UTF8  | Set-Content -Encoding UTF8 $pbitEntryNewName


        Remove-Item $pbitPartFile.FullName -Force -Recurse
        
        [System.IO.Directory]::Move($pbitMUTmpExtractDir, $pbitMUExtractDir)    


}

function PackPbitDataMashup
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo] $pbitPartDir,
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $pbitconfig

    )

        if (!$pbitPartDir.Exists){ return}

        $pbitMUPkgTarget = $pbitPartDir.FullName 

        $pbitMUPkgTargetPkg = $pbitMUPkgTarget + ".pkg"

        $pbitPartDir.MoveTo($pbitPartDir.FullName + "tmp")

        $pbitPartDir.FullName


        CreatePackageFromDirectory -packageRootDir $pbitPartDir.FullName -packageFile $pbitMUPkgTargetPkg


        ## Need to clean up package....

        $packagePartBytes = [System.IO.File]::ReadAllBytes($pbitMUPkgTargetPkg)
        $extraPartBytes =  [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($pbitPartDir.FullName, "extraBytes"))

        $stream = [System.IO.File]::Open($pbitMUPkgTarget, [System.IO.FileMode]::Create)

        $writer =  New-Object System.IO.BinaryWriter ($stream, [System.Text.Encoding]::UTF8)

        $writer.Write([int32]0)
        $writer.Write([int32]$packagePartBytes.Length)
        $writer.Write($packagePartBytes)




        "Packing Extra part bytes count " + $extraPartBytes.Length

        $writer.Write($extraPartBytes)

        $writer.Close()
        $stream.Close()



        #[System.IO.Compression.ZipFile]::CreateFromDirectory($pbitPartDir.FullName, $pbitMUPkgTarget)


       Remove-Item $pbitMUPkgTargetPkg -Force -Recurse

       #Remove-Item $pbitPartDir.FullName -Force -Recurse
        
       # [System.IO.Directory]::Move($pbitMUTmpExtractDir, $pbitMUExtractDir)    

}

function UnpackPbitJsonPartObsolete
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile,
       [ValidateNotNullOrEmpty()]
        [Text.Encoding] $originalEncoding

    )

    $pbitEntryNewName = $pbitPartFile.FullName + ".json"

    $txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName, $originalEncoding)

    [IO.File]::WriteAllText($pbitEntryNewName, $txtcontent, $Utf8NoBomEncoding)

    #$txtcontent | Set-Content -Encoding UTF8 $pbitEntryNewName

    Remove-Item $pbitPartFile.FullName -Force -Recurse

}

function UnpackPbitPartFile
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile,
       [ValidateNotNullOrEmpty()]
        [Text.Encoding] $originalEncoding,
        [string]$newFileExtension
    )

    if (!([String]::IsNullOrEmpty($newFileExtension))){
        $partFileNewName = $pbitPartFile.BaseName + "." + $newFileExtension
    }

    Rename-Item -Path $pbitPartFile.FullName -NewName $partFileNewName

    return

    #####  The code below may be obsolete unless file encoding is desired.  #####


   # Copy-Item  $pbitPartFile.FullName -Destination ($pbitPartFile.FullName + "_orig")

   #$tmpPbitPartFileName = [IO.Path]::Combine($pbitPartFile.DirectoryName,(New-Guid).ToString())
    
    $tmpPbitPartFileName = $pbitPartFile.FullName + ".unpack"

    #$txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName )

    $contentBytes = [IO.File]::ReadAllBytes($pbitPartFile.FullName)

    #NOTEWORTHY:  The following conversion does not appear to be happening.  This code may need to be reeavlauted.
       
    $convertedBytes = [Text.Encoding]::Convert($originalEncoding, [Text.Encoding]::UTF8 , $contentBytes)

    [IO.File]::WriteAllBytes($tmpPbitPartFileName, $convertedBytes)


    $txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName, $originalEncoding)

    #$txtcontent = Get-Content $pbitPartFile.FullName -Encoding 

    [IO.File]::WriteAllText($tmpPbitPartFileName2, $txtcontent, $Utf8NoBomEncoding)

    #$txtcontent | Set-Content  $tmpPbitPartFileName2 -Encoding UTF8
     

    $partFileFullName = $pbitPartFile.FullName

    $partFileNewName = $pbitPartFile.Name

    if (!([String]::IsNullOrEmpty($newFileExtension))){
        $partFileNewName = $pbitPartFile.BaseName + "." + $newFileExtension
    }

   Remove-Item $partFileFullName -Force -Recurse

  # Rename-Item -Path $tmpPbitPartFileName -NewName $partFileNewName

   Copy-Item $tmpPbitPartFileName -Destination ([IO.Path]::Combine($pbitPartFile.DirectoryName,$partFileNewName))

}

function PackPbitPartFile
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile,
       [ValidateNotNullOrEmpty()]
        [Text.Encoding] $originalEncoding,
        [ValidateNotNullOrEmpty()]
        [boolean] $removeExtension
    )


    $tmpPbitPartFileName = [IO.Path]::Combine($pbitPartFile.DirectoryName,(New-Guid).ToString())

    $contentBytes = [IO.File]::ReadAllBytes($pbitPartFile.FullName)

    $convertedBytes = [Text.Encoding]::Convert([Text.Encoding]::UTF8 , $originalEncoding, $contentBytes)

    [IO.File]::WriteAllBytes($tmpPbitPartFileName, $convertedBytes)



    $partFileFullName = $pbitPartFile.FullName

    $partFileNewName = $pbitPartFile.Name

    if ($removeExtension){
        $partFileNewName = $pbitPartFile.BaseName
    }

    Remove-Item $partFileFullName -Force -Recurse

    Rename-Item -Path $tmpPbitPartFileName -NewName $partFileNewName



   # $txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName, $Utf8NoBomEncoding)
   # [IO.File]::WriteAllText($pbitPartFile.FullName, $txtcontent,$originalEncoding)

   # if ($removeExtension){
    #    Rename-Item -Path $pbitPartFile.FullName -NewName $pbitPartFile.BaseName
   # }  
    
      

}

function PackPbitJsonPartObsolete
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile,
       [ValidateNotNullOrEmpty()]
        [Text.Encoding] $originalEncoding

    )

    $pbitEntryNewName = $pbitPartFile.DirectoryName + "\" + $pbitPartFile.BaseName

    # $txtcontent = Get-Content $pbitPartFile.FullName -Encoding UTF8

      $txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName, $Utf8NoBomEncoding)

     #1251    [Text.Encoding]::GetEncoding(1251)



     [IO.File]::WriteAllText($pbitEntryNewName, $txtcontent,$originalEncoding)

    Remove-Item $pbitPartFile.FullName -Force -Recurse

}

function UnpackPbitTxtPartObsolete
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile

    )

    $pbitEntryNewName = $pbitPartFile.FullName + ".txt"

    $txtcontent = [IO.File]::ReadAllText($pbitPartFile.FullName, [Text.Encoding]::GetEncoding(1251))

    $txtcontent | Set-Content -Encoding UTF8 $pbitEntryNewName

    Remove-Item $pbitPartFile.FullName -Force -Recurse

}

function PackPbitTxtPartObsolete
{
    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile

    )

    $pbitEntryNewName = $pbitPartFile.DirectoryName + "\" + $pbitPartFile.BaseName

     $txtcontent = Get-Content $pbitPartFile.FullName -Encoding UTF8

     [IO.File]::WriteAllText($pbitEntryNewName, $txtcontent, [Text.Encoding]::GetEncoding(1251))

    # | Set-Content -Encoding UTF16LE $pbitEntryNewName

    Remove-Item $pbitPartFile.FullName -Force -Recurse

}

function UnpackPbitPart {

    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile

    )

       $pbitEntryExt = $pbitPartFile.Extension
    

         if ($pbitEntryExt -eq ""){

                if ($pbitEntry.BaseName -eq "DataMashup")
             
             {
             
                   UnpackPbitDataMashup -pbitPartFile $pbitEntry
             }


                elseif ($pbitEntry.BaseName -eq "DataModelSchema" -or
                        $pbitEntry.BaseName -eq "DiagramLayout" -or
                        $pbitEntry.BaseName -eq "Metadata" -or
                        $pbitEntry.BaseName -eq "Settings" )
                {
                    #UnpackPbitJsonPart -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251))
                    UnpackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251)) -newFileExtension "json"
                }
                elseif ($pbitEntry.BaseName -eq "Connections")
                {
                    UnpackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding $Utf8NoBomEncoding -newFileExtension "json"
                }

                #elseif ($pbitEntry.BaseName -eq "SecurityBindings")
                #{
                    # Do nothing with security bindings.
                #}
                elseif ($pbitEntry.BaseName -eq "Version")
                {
                    #UnpackPbitTxtPart  -pbitPartFile $pbitEntry
                    UnpackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251)) -newFileExtension "txt"
                }
                else
                {
                    # Do nothing
                }

               #Remove-Item $pbitEntry.FullName -Force -Recurse

  

         }


    }



function PackPbitPart {

    param (
       [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $pbitPartFile,
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $pbitconfig,
        [Guid] $targetwsid,
        [PSCustomObject[]] $dataflows

    )


                PackPbitDataMashup -pbitPartDir ($pbitPartFile.DirectoryName + "\DataMashup") -pbitconfig $pbitconfig

                if ($pbitEntry.BaseName -eq "DataModelSchema" -or
                        $pbitEntry.BaseName -eq "DiagramLayout" -or
                        $pbitEntry.BaseName -eq "Metadata" -or
                        $pbitEntry.BaseName -eq "Settings" )
                {
                   PackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251)) -removeExtension $true

                   #PackPbitJsonPart -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251))
                }
                elseif ($pbitEntry.BaseName -eq "Connections")
                {
                  PackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding $Utf8NoBomEncoding -removeExtension $true
                  #PackPbitJsonPart -pbitPartFile $pbitEntry -originalEncoding $Utf8NoBomEncoding
                }

                #elseif ($pbitEntry.BaseName -eq "SecurityBindings")
                #{
                    # Do nothing with security bindings.
                #}
                elseif ($pbitEntry.BaseName -eq "Version")
                {
                     PackPbitPartFile -pbitPartFile $pbitEntry -originalEncoding ([Text.Encoding]::GetEncoding(1251)) -removeExtension $true

                     #PackPbitTxtPart  -pbitPartFile $pbitEntry
                }
                else
                {
                    # Do nothing
                }


    }

function UnpackPbitFile {

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitFile,
        [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $unpackDir
    )


    "Unpacking Pbit File " + $pbitFile.Name

    $pbitExtractDir = $unpackDir.FullName 


    ExportPackageToDirectory -packageFile $pbitFile -exportDir $pbitExtractDir


    $pbitEntries = Get-ChildItem -Path $pbitExtractDir -File 

    foreach ($pbitEntry in $pbitEntries)
    {
        UnpackPbitPart -$pbitEntry
    }
}


function PackPbitFile {

    param (
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $pbitRootDir,
        [ValidateNotNullOrEmpty()]
       [System.IO.FileInfo] $pbitFile,
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $pbitconfig,
        [Guid] $targetwsid,
        [PSCustomObject[]] $dataflows
    )


#    $packPbitTmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($pbitFile), (New-Guid).ToString())

    $packPbitTmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($pbitFile), "PACK-" + $pbitFile.BaseName)

    "Packing Pbit File " + $pbitFile.Name

    $packPbitTmpDir 


    if (Test-Path $packPbitTmpDir ) 
    {
        Remove-Item -path $packPbitTmpDir -recurse -force            
    }
     
     New-Item -Path $packPbitTmpDir -ItemType Directory

     Copy-Item ($pbitRootDir.FullName + "*") -Destination $packPbitTmpDir -Recurse


     #Update the MashupDefaultValues now.

     SetPbitMashupParameterDefaultValues -pbitunpackdir $packPbitTmpDir -pbitConfig $pbitconfig -pbitfile $pbitFile -targetwsid $targetwsid -dataflows $dataflows

     #Update the Datamodel Expression default values now.

     SetPbitDataModelSchemaParameterDefaultValues -pbitunpackdir $packPbitTmpDir -pbitConfig $pbitconfig -pbitfile $pbitFile -targetwsid $targetwsid -dataflows $dataflows


    $pbitEntries = Get-ChildItem -Path $packPbitTmpDir -File 

    foreach ($pbitEntry in $pbitEntries)
    {
       # $pbitEntry

        PackPbitPart -pbitPartFile $pbitEntry -pbitconfig $pbitconfig
    }


    if (Test-Path $pbitFile ) 
    {
        Remove-Item -path $pbitFile -recurse -force            
    }
  

    CreatePackageFromDirectory -packageRootDir $packPbitTmpDir -packageFile $pbitFile


    if (Test-Path $packPbitTmpDir ) 
    {
      Remove-Item -path $packPbitTmpDir -recurse -force            
    }


}

function UnpackProjectPbits {

    param (
        [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $projectRootDir
    )


    $pbitDir = $projectRootDir.FullName + "\pbit\"

    $pbitFilter = $pbitDir + "*.pbit"


    if (!(Test-Path $projectRootDir)) 
    {
         "Project Root Directory $projectRootDir does not exist"
         return
    }

    if (!(Test-Path $pbitDir)) 
    {
        "Project does not have a proper pbit folder.  For this project, pbit files should be stored in the following directory:  $pbitDir"
        return
    }

    $pbitFiles = Get-ChildItem -Path $pbitFilter

    foreach ($pbitfile in $pbitFiles)
    {
       $pbitExtractDir = $pbitDir + $pbitFile.BaseName + "\"

       UnpackPbitFile -pbitFile $pbitfile -unpackDir $pbitExtractDir

    }

    CreateOrUpdatePbitConfig -projectRootDir $projectRootDir 

}


function PackProjectPbits {

    param (
        [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $projectRootDir,
       [ValidateNotNullOrEmpty()]
       [System.IO.DirectoryInfo] $targetPackedDir,
       [Guid] $targetwsid,
       [System.IO.FileInfo] $deployconfigfile,
       [String] $configuration
    )

     $wsid =  [Guid]::Empty

    $pbitDir = $projectRootDir.FullName + "\pbit\"

    $pbitFilter = $pbitDir + "*.pbit"


    if (!(Test-Path $projectRootDir)) 
    {
         "Project Root Directory $projectRootDir does not exist"
         return
    }

    if (!(Test-Path $pbitDir)) 
    {
        "Project does not have a proper pbit folder.  For this project, pbit files should be stored in the following directory:  $pbitDir"
        return
    }

    if (!($targetPackedDir.Exists)) 
    {
            Write-Host ("Creating Directory " + $targetPackedDir) -ForegroundColor Gray
            $targetPackedDir.Create()
    }


    #Ensure pbitConfig.json exists.

    if ($deployconfigfile)
    {
        $PbitConfigFile = $deployconfigfile
    }
    else
    {
        $PbitConfigFile = GetPbitConfigFileInfo -pbitRootDir $targetPackedDir -configuration $configuration

        if (!$PbitConfigFile.Exists)
        {
            $PbitConfigFile = GetPbitConfigFileInfo -pbitRootDir $pbitDir -configuration $configuration
        }
    }


    $PbitConfig = Get-Content -Path $PbitConfigFile.FullName | ConvertFrom-Json


    $pbitFiles = Get-ChildItem -Path $pbitFilter

    $getDataFlows = [PSCustomObject[]]@()

    if($targetwsid)
    {

        $wsid = $targetwsid

        if (!($PbiWorkspaceExportImported)){

        . "$PSScriptRoot\PbiWorkspaceExportImport.ps1"

        }

        $getDataFlows = GetWorkspaceDataflows -workspaceid $targetwsid

    }


    foreach ($pbitfile in $pbitFiles)
    {

       $pbitExtractDir = $pbitDir + $pbitFile.BaseName + "\"

       $packTarget = [IO.Path]::Combine($targetPackedDir.FullName, $pbitfile.BaseName + ".pbit")

       PackPbitFile -pbitRootDir $pbitExtractDir -pbitFile $packTarget -pbitconfig $PbitConfig -targetwsid $wsid -dataflows $getDataFlows
    }

}


