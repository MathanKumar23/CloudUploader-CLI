#!/bin/bash

# A script that will allow users to upload file to azure blob storage using CLI
# https://github.com/
# - Written by: Mathan Kumar 
# - Completed: March 30, 2024

#authenticate into azure
authentication{
    echo "going to login"
    az login --use-device-code
    echo "You're logged in."
}

# list 5 recommended regions
recommandedRegions() {
    #sort out top 5 recommanded regioon
    regions_array=($( az account list-locations --query "[?metadata.regionCategory=='Recommended'].{Name:name}" -o tsv | head -n 5))
    # Trim whitespace from each element in the array
    for ((i=0; i<${#regions_array[@]}; i++)); do
        regions_array[i]=$(echo "${regions_array[i]}" | tr -d '[:space:]')
    done

    # Print out the trimmed regions
    for i in "${regions_array[@]}"
    do
       echo "$i"
    done
}

#prompt user to select region from recommended
checkRegion() {
    local region_exist=false # initialize region exist variable 
    while [ "$region_exist" = false ]; do
        echo "Cheking recommanded regions...."
        sleep 1
        #calling function to print recommanded regions
        recommandedRegions
        sleep 1
        #prompt user to provide region name
        read -p "Please enter the region name in above : " region_name
        
        for j in "${regions_array[@]}" ; do
            if [ "$region_name" = "$j" ] ; then
                region_exist=true
                #print the selected region
                echo "Region selected : $region_name"
                break
            fi
        done
        #check if region exist in the list
        if [ "$region_exist" = false ]; then
            echo "Region not existed in above recommanded. Please enter valid from the list"
        fi
    done

}


# creating resource group
createResourceGroup() {
    read -p "Enter the Resource group name: " resource_group
    while true ; do
    # Check if resource group exists in tenant
        if az group show --name "$resource_group" &> /dev/null ; then
            read -p "Resoure group $resource_group already exist in region $region_name. Please enter another name: " resource_group
        else
            echo "Creating the resource group $resource_group in $region_name region.."
            #az commad to create new resource group
            az group create -g $resource_group -l $region_name | grep provisioningState
            az group list -o table
            break
        fi
    done

}

#creating storage account
createStorageAccount() {
     # Fetch the location of the resource group
    location=$(az group show --name "$resource_group" --query "location" --output tsv)
            
    read -p "Enter the Storage account name: " storage_account
    while true ; do
        # Check if storage account exists in tenant
        if [ "$(az storage account check-name --name "$storage_account" --query nameAvailable)" = "true" ] ; then
            echo "Storage account name '$storage_account' is available."
            break
        else 
            read -p "Storage account $storage_account already exist. Please enter another name: " storage_account
        fi
    done
    
    echo "Creating the storgage account $storage_account in $resource_group resource group $location region.."
    #craeting storage account
    az storage account create --name $storage_account --resource-group $resource_group --location $location --sku Standard_LRS | grep provisioningState
    sleep 2
    az storage account list --query "[].{ResourceGroup: resourceGroup, StorageAccountName: name}" -o table

}


#creating new container
createContainer() {
    read -p "Enter the Conatiner name: " container_name
    while true ; do
    # Check if container exists in tenant
        if az storage container show --name $container_name --account-name $storage_account --auth-mode login &> /dev/null; then
            read -p "Container $container_name already exist. Please enter another name: " container_name
        else
            echo "Container name availbale to use."
            echo "Creating the contatiner $container_name in $storage_account reource group $resource_group $location region.."
            #az commad to create new container in storage account
            az storage container create --name $container_name --account-name $storage_account --account-key $storage_key | grep provisioningState
            az storage container list --account-name $storage_account -o table
            break
        fi
    done

}

#Upload File 
uploadFile() {
    echo "uploading file....."
    #az command to upload file in storage container
    az storage blob upload --account-name $storage_account --container-name $container_name --name $file_name --file $file_name --account-key $storage_key
    
    #check if file is uploaded successfullly or not
    if [ $? -eq 0 ]; then
    echo "File uploaded successfullly..!"
    else
    echo "Error: Failed to upload a file"
    fi
}



    #Non-Function script

    file_name=$1  # store the file/path in file_name variable

    echo "Would you like to create new resource group? (Y/N)"
    read answer

    authentication

# check if user provided resource group available, if not prompt user again to type correct resource group
while true; do
   if [[  "$answer" == "Yes" || "$answer" == "Y" || "$answer" == "yes" ||  "$answer" == "y" ]]; then 
        # calling region function to select region
        checkRegion
        #calllinf resource group function to create new RG
        createResourceGroup
        break # Exit the loop after creating new resource group
    elif [[ "$answer" == "No" || "$answer" == "N" || "$answer" == "no" || "$answer" == "NO" ]]; then
        echo "What is the name of the existing resource group you would like to use?"
        read resource_group
        # Check if user provided resource group exists
        if az group show --name "$resource_group" &> /dev/null ; then
            echo "Resource group '$resource_group' exists in Azure."
            break # Exit the loop if resource gruop exist
        else
            echo "Resource group '$resource_group' does not exist in Azure. Create new reource group (Y/yes)/use existing one (N/no) : "
            read answer
            sleep 1
        fi
    else
        read -p "Invalid input. Please enter Yes/Y or No/N. " answer
    fi
done


    echo "Would you like to create Storage account(Y/N) : "
    read answer

# check if user provided storage acc available, if not prompt user again to type correct storage acc
while true; do
    if [[ "$answer" == "Yes" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "y" ]]; then 
        createStorageAccount
        break
    elif [[ "$answer" == "No" || "$answer" == "N" || "$answer" == "no" || "$answer" == "NO" ]]; then
        echo "What is the storage account name?"
        read storage_account
        # Check if user provided storage account exists
        if az storage account show --name "$storage_account" --resource-group $resource_group &> /dev/null; then
            echo "Storage account '$storage_account' exists in Azure."
            break  # Exit the loop if storage account exists
        else
            echo "Storage account '$storage_account' does not exist in Azure."
            read -p "Would you like to create a storage account(Yes/Y)?/ Use existing storage account (No/N): " answer
        fi
    else
        read -p "Invalid input. Please enter Yes/Y or No/N." answer
    fi
done

    #Azure CLI command and store the storage key in a variable
    storage_key=$(az storage account keys list --account-name $storage_account --resource-group $resource_group --query '[0].value' -o tsv)
    echo "\nStorage key ::  $storage_key"

    echo "Would you like to create Container(Y/N): "
    read answer

# check if user provided conatiner available, if not prompt user again to type correct conatiner name
while true; do
    if [[ "$answer" == "Yes" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "y" ]]; then 
        createContainer
        break  # Exit the loop after creating the container
    elif [[ "$answer" == "No" || "$answer" == "N" || "$answer" == "no" || "$answer" == "NO" ]]; then
        echo "What is the Container name?"
        read container_name
        # Check if user provided container exists
        if az storage container show --name "$container_name" --account-name "$storage_account" --auth-mode login &> /dev/null; then
            echo "container '$container_name' exists in Azure storage account "$storage_account"."
            break  
        else
            echo "container '$container_name' do not exist in your Azure storage account "$storage_account""
            read -p "Would you like to create a container(Yes/Y)?/ Use existing container (No/N) : " answer
        fi
    else
        read -p "Invalid input. Please enter Yes/Y or No/N." answer
    fi
done

#Calling function to upload file
uploadFile