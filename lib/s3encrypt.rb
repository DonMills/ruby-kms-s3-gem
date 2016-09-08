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

  def self.upload_key(s3client,newkeyblob,remote_filename,bucket,sse)
      keyfile_name= remote_filename+ ".key"
      newkeyblob64 = Base64.encode64(newkeyblob)
      if sse == "none"
         s3client.put_object({body: newkeyblob64,
                               key: keyfile_name,
                               bucket: bucket
                               })
      else
        s3client.put_object({
          body: newkeyblob64,
          key: keyfile_name,
          bucket: bucket,
          server_side_encryption: sse
          })
      end
  end


  def self.upload_file(s3client,plaintext_key,local_filename,remote_filename,bucket,sse)
    begin
      filebody = File.new(local_filename)
      s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                              client: s3client)
      if sse == "none"
        res = s3enc.put_object(bucket: bucket,
                               key: remote_filename,
                               body: filebody
                               )
      else
      res = s3enc.put_object(bucket: bucket,
                             key: remote_filename,
                             server_side_encryption: sse,
                             body: filebody
                             )
      end
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

  def self.fetch_file(s3client,plaintext_key,local_filename,remote_filename,bucket)
    begin
      s3enc = Aws::S3::Encryption::Client.new(encryption_key: plaintext_key,
                                              client: s3client)
      res = s3enc.get_object(bucket: bucket,
                             key: remote_filename,
                             response_target: local_filename)
    rescue Aws::S3::Errors::ServiceError => e
      puts "retrieval failed: #{e}"
    end
  end

  def self.getfile(local_filename, remote_filename, bucket, app_context)
    s3client = Aws::S3::Client.new()
    keyval= fetch_key(s3client,remote_filename,bucket)
    keyvalue = decrypt_key(keyval,app_context)
    fetch_file(s3client,keyvalue,local_filename,remote_filename,bucket)
  end

  def self.putfile(local_filename, remote_filename, bucket, app_context, master_key, sse="none")
    newkeyblob, newkeyplain = fetch_new_key(app_context, master_key)
    #write_enc_key(newkeyblob,filename)
    s3client = Aws::S3::Client.new()
    upload_key(s3client,newkeyblob,remote_filename,bucket,sse)
    upload_file(s3client,newkeyplain,local_filename,remote_filename,bucket,sse)
  end

  def self.putfile_ssekms(local_filename, remote_filename, bucket, app_context, master_key)
    putfile(local_filename, remote_filename, bucket, app_context, master_key,"aws:kms")
  end

  def self.putfile_sses3(local_filename, remote_filename, bucket, app_context, master_key)
    putfile(local_filename, remote_filename, bucket, app_context, master_key,"AES256")
  end

end
