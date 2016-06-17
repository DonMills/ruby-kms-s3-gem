require "s3encrypt/version"
require 'aws-sdk'
require 'base64'

module S3encrypt
  ########################################
  #Below might be needed on Windows, if so uncomment
  ########################################
  Aws.use_bundled_cert!


  ########################################
  # This was to write the encrypted key locally, but I figured out how to do it all
  # in memory.  You could still uncomment and use if you wanted local encrypted key copy
  # Plaintext key never touches filesystem.
  ########################################
  #def write_enc_key(keyblob,name)
  #  keyname = name + ".key"
  #  keyfile = File.new(keyname, "w")
  #  keyfile.write(keyblob)
  #  keyfile.close
  #  return keyname
  #end

  ########################################
  # Put your KMS master key id under key_id
  ########################################

  def self.fetch_new_key(app_context, master_key)
    kms_client = Aws::KMS::Client.new()
    genkey = kms_client.generate_data_key({
      key_id: master_key,
      key_spec: "AES_256",
      encryption_context: {
        "Application" => app_context,
        }
      })
      return genkey.ciphertext_blob, genkey.plaintext
  end

  #########################################
  # This whole thing refused to work for hours
  # until I base64 encoded the key on upload and
  # decoded on download...gave invalidciphertext exception
  #########################################

  def self.upload_key(s3client,newkeyblob,filename,bucket)
      keyfile_name= filename+ ".key"
      newkeyblob64 = Base64.encode64(newkeyblob)
    s3client.put_object({
      body: newkeyblob64,
      key: keyfile_name,
      bucket: bucket
      })
  end


  def self.upload_file(s3client,plaintext_key,filename,bucket)
    begin
      filebody = File.new(filename)
      s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                              client: s3client)
      res = s3enc.put_object(bucket: bucket,
                             key: filename,
                             body: filebody)
    rescue Aws::S3::Errors::ServiceError => e
      puts "upload failed: #{e}"
    end
  end

  def self.decrypt_key(keyvalue,app_context)
    kms_client = Aws::KMS::Client.new()
    plainkey = kms_client.decrypt(
      ciphertext_blob: keyvalue,
      encryption_context: {
        "Application" => app_context,
        }
    )
      return plainkey.plaintext
  end


  def self.fetch_key(s3client,filename,bucket)
      keyfile_name= filename+ ".key"
      keyvalue=s3client.get_object(
      key: keyfile_name,
      bucket: bucket
      )
      keyval64 = Base64.decode64(keyvalue.body.read)
      return keyval64
  end

  def self.fetch_file(s3client,plaintext_key,filename,bucket)
    begin
      s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                              client: s3client)
      res = s3enc.get_object(bucket: bucket,
                             key: filename,
                             response_target: filename)
    rescue Aws::S3::Errors::ServiceError => e
      puts "upload failed: #{e}"
    end
  end

  def self.getfile(filename, bucket, app_context)
    s3client = Aws::S3::Client.new(region: 'us-east-1')
    keyval= fetch_key(s3client,filename,bucket)
    keyvalue = decrypt_key(keyval,app_context)
    fetch_file(s3client,keyvalue,filename,bucket)
  end

  def self.putfile(filename, bucket, app_context, master_key)
    newkeyblob, newkeyplain = fetch_new_key(app_context, master_key)
    #write_enc_key(newkeyblob,filename)
    s3client = Aws::S3::Client.new(region: 'us-east-1')
    upload_key(s3client,newkeyblob,filename,bucket)
    upload_file(s3client,newkeyplain,filename,bucket)
  end
end
